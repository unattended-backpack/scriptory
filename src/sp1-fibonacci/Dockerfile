# Use the same base image as the main project for consistency.
ARG BUILD_IMAGE=unattended/petros:latest
FROM ${BUILD_IMAGE}

# Copy the integration test project. Cargo.lock is copied so `cargo prove
# build` and the evm binary build use the pinned dep graph instead of
# freshly resolving and pulling crate versions that require a newer rustc
# than the Succinct toolchain ships with (e.g. constant_time_eq@0.4.3
# requires rustc 1.95 while Succinct currently ships 1.88-dev).
WORKDIR /test
COPY src/sp1-fibonacci/Cargo.toml Cargo.toml
COPY src/sp1-fibonacci/Cargo.lock Cargo.lock
COPY src/sp1-fibonacci/lib/ lib/
COPY src/sp1-fibonacci/program/ program/
COPY src/sp1-fibonacci/script/ script/

# The shared `fibonacci` crate. The sp1-fibonacci program path-deps to
# `../../fibonacci`, which from `/test/program/` resolves to `/fibonacci/`
# inside this image. Cargo will error on workspace resolution if this
# directory does not exist.
COPY src/fibonacci/ /fibonacci/

# Build the ZK program (this creates the ELF file).
WORKDIR /test/program
RUN cargo prove build --locked

# Build the evm binary.
WORKDIR /test/script
RUN cargo build --release --bin evm --locked

# Configure and run the test.
# There are no assets on that private key.
WORKDIR /test/script
ENV SP1_PROVER=network
ENV NETWORK_RPC_URL=http://hierophant:9000
ENV NETWORK_PRIVATE_KEY=9edaae0d468d0dbb808b2f4ac28b4319186ab9824b9f28d9ac1ad99f8868bb96
ENV RUST_LOG=info
CMD ["cargo", "run", "--release", "--bin", "evm", "--", "--n", "10", "--system", "plonk"]
