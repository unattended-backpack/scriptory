//! End-to-end SP1 demonstration driver against a Hierophant prover network.
//!
//! Requests a single fibonacci proof in the `--system`-selected mode. SP1
//! has four proving modes:
//!   core        raw STARK, fastest to prove, not EVM-verifiable
//!   compressed  core STARK compressed into a single recursive proof
//!   plonk       compressed STARK wrapped into a Plonk SNARK (EVM-verifiable)
//!   groth16     compressed STARK wrapped into a Groth16 SNARK (EVM-verifiable)
//!
//! All four are exposed so scriptory can confirm CUDA-accelerated proof
//! generation across SP1's full mode menu. For the EVM-verifiable wraps
//! (plonk and groth16) the client additionally writes a JSON fixture to
//! `contracts/src/fixtures/{plonk,groth16}-fixture.json` containing
//! `(vkey, publicValues, proof)` in the exact shape SP1's Solidity verifier
//! expects; that fixture exists for operators who want to wire up an
//! out-of-band Foundry / Hardhat test against a stock SP1 verifier
//! contract. core and compressed proofs have no onchain byte
//! representation (`proof.bytes()` panics on them) so the fixture step is
//! skipped for those modes.
//!
//! The proof itself is verified server-side by Hierophant before being
//! returned to this client (see `prover_network_service.rs:Verified
//! proof ...!!`), so we do not also re-verify here. That keeps scriptory's
//! test client free of the SP1 circuit artifacts the SDK's `client.verify`
//! would otherwise need.
//!
//! You can run this script using the following command:
//! ```shell
//! RUST_LOG=info cargo run --release --bin evm -- --system groth16
//! ```
//! or
//! ```shell
//! RUST_LOG=info cargo run --release --bin evm -- --system core
//! ```
use alloy_sol_types::SolType;
use clap::{Parser, ValueEnum};
use fibonacci_lib::PublicValuesStruct;
use serde::{Deserialize, Serialize};
use sp1_sdk::{
    include_elf, utils, HashableKey, Prover, ProverClient, SP1ProofWithPublicValues, SP1Stdin,
    SP1VerifyingKey,
};
use std::path::PathBuf;

/// The ELF (executable and linkable format) file for the Succinct RISC-V zkVM.
pub const FIBONACCI_ELF: &[u8] = include_elf!("fibonacci-program");

/// The arguments for the EVM command.
#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
struct EVMArgs {
    #[arg(long, default_value = "20")]
    n: u32,
    #[arg(long, value_enum, default_value = "groth16")]
    system: ProofSystem,
}

/// Enum representing the available proof systems.
#[derive(Copy, Clone, PartialEq, Eq, PartialOrd, Ord, ValueEnum, Debug)]
enum ProofSystem {
    Core,
    Compressed,
    Plonk,
    Groth16,
}

/// A fixture that can be used to test the verification of SP1 zkVM proofs inside Solidity.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
struct SP1FibonacciProofFixture {
    a: u32,
    b: u32,
    n: u32,
    vkey: String,
    public_values: String,
    proof: String,
}

fn main() {
    // Setup the logger.
    utils::setup_logger();

    // Parse the command line arguments.
    let args = EVMArgs::parse();
    println!("n: {}", args.n);
    println!("Proof System: {:?}", args.system);

    // Setup the prover client.
    let client = ProverClient::builder().network().build();

    // Setup the program.
    let (pk, vk) = client.setup(FIBONACCI_ELF);

    // Setup the inputs.
    let mut stdin = SP1Stdin::new();
    stdin.write(&args.n);

    // Generate the proof based on the selected proof system. Hierophant
    // verifies the resulting proof server-side before storing and returning
    // it; if this call returns Ok the proof is valid.
    let proof = match args.system {
        ProofSystem::Core => client.prove(&pk, &stdin).core().run(),
        ProofSystem::Compressed => client.prove(&pk, &stdin).compressed().run(),
        ProofSystem::Plonk => client.prove(&pk, &stdin).plonk().run(),
        ProofSystem::Groth16 => client.prove(&pk, &stdin).groth16().run(),
    }
    .expect("failed to generate proof");

    // Only the EVM-verifiable wraps have a meaningful Solidity-encoded byte
    // representation; `proof.bytes()` panics on core and compressed proofs
    // because those modes don't have an onchain encoding to emit. Skip the
    // fixture step for those two modes.
    match args.system {
        ProofSystem::Plonk | ProofSystem::Groth16 => {
            create_proof_fixture(&proof, &vk, args.system);
        }
        ProofSystem::Core | ProofSystem::Compressed => {
            println!(
                "Skipping fixture write for {:?} (no onchain byte representation).",
                args.system
            );
        }
    }
}

/// Create a fixture for the given proof.
fn create_proof_fixture(
    proof: &SP1ProofWithPublicValues,
    vk: &SP1VerifyingKey,
    system: ProofSystem,
) {
    // Deserialize the public values.
    let bytes = proof.public_values.as_slice();
    let PublicValuesStruct { n, a, b } = PublicValuesStruct::abi_decode(bytes).unwrap();

    // Create the testing fixture so we can test things end-to-end.
    let fixture = SP1FibonacciProofFixture {
        a,
        b,
        n,
        vkey: vk.bytes32().to_string(),
        public_values: format!("0x{}", hex::encode(bytes)),
        proof: format!("0x{}", hex::encode(proof.bytes())),
    };

    // The verification key is used to verify that the proof corresponds to the execution of the
    // program on the given input.
    //
    // Note that the verification key stays the same regardless of the input.
    println!("Verification Key: {}", fixture.vkey);

    // The public values are the values which are publicly committed to by the zkVM.
    //
    // If you need to expose the inputs or outputs of your program, you should commit them in
    // the public values.
    println!("Public Values: {}", fixture.public_values);

    // The proof proves to the verifier that the program was executed with some inputs that led to
    // the give public values.
    println!("Proof Bytes: {}", fixture.proof);

    // Save the fixture to a file.
    let fixture_path = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../contracts/src/fixtures");
    std::fs::create_dir_all(&fixture_path).expect("failed to create fixture path");
    std::fs::write(
        fixture_path.join(format!("{:?}-fixture.json", system).to_lowercase()),
        serde_json::to_string_pretty(&fixture).unwrap(),
    )
    .expect("failed to write fixture");
}
