# Scriptory

> Write the vision; make it plain on tablets, so he may run who reads it.

A simple solution for hosted proof production using [Hierophant](https://github.com/unattended-backpack/hierophant), [Magister](https://github.com/unattended-backpack/magister), and Contemplant. This Docker Compose setup runs a complete zkVM prover network with GPU-accelerated proof generation on Vast, demonstrated with a fibonacci example program.

## Running

Scriptory uses a [Makefile](./Makefile) to simplify common operations. The available targets can be viewed by running `make help`. The most common workflow is outlined below.

### Initial Setup

Before running Scriptory for the first time, you must initialize the configuration files. Run `make init` to create `.env`, `hierophant.toml`, and `magister.toml` from their example templates. This will copy `.env.example` to `.env`, `hierophant.example.toml` to `hierophant.toml`, and `magister.example.toml` to `magister.toml`.

The `.env` file contains the minimal configuration required to run Scriptory. You must edit this file and provide three critical values:

- `THIS_HIEROPHANT_IP`: Your public IP address or hostname for Hierophant artifact uploads and downloads. For local testing with remote Contemplants, use your WAN IP with proper port forwarding (9000, 9010).
- `HIEROPHANT_IP`: IP address that Contemplants use to connect to Hierophant via WebSocket. Should match `THIS_HIEROPHANT_IP` for most deployments.
- `VAST_API_KEY`: Your Vast.ai API key for managing GPU instances. Obtain this from [https://vast.ai/](https://vast.ai/) under Account > API Keys.

The remaining values in `.env` have sensible defaults:
- `VAST_TEMPLATE_HASH`: Template for creating Contemplant instances (default provided).
- `NUMBER_INSTANCES`: Number of Contemplant instances to maintain (default: 1).
- `CONTEMPLANT_PROVER_TYPE`: Whether the Contemplant instances should use `cuda` proving or `cpu` proving (default: `cuda`).
- `CONTEMPLANT_MOONGATE_ENDPOINT`: The endpoint a Contemplant instance should use for a Moongate prover (default provided).
- `CONTEMPLANT_SSH_AUTHORIZED_KEYS`: Any SSH public keys for gaining debug access to Contemplant instances.

The TOML files (`hierophant.toml` and `magister.toml`) contain detailed service configuration and work out of the box for Docker Compose deployments. Values in `.env` will override TOML settings where applicable. Review the TOML files if you need to customize advanced settings such as worker timeouts, Vast.ai query parameters, or artifact storage limits.

### Starting Services

Once configuration is complete, start the services with `make scriptory` (foreground) or `make scriptory-d` (detached). This command will:

1. Build the fibonacci example Docker image.
2. Start Hierophant on ports 9000 (gRPC) and 9010 (HTTP/WebSocket).
3. Start Magister on port 8555, which will:
   - Connect to Hierophant.
   - Create and maintain the configured number of Contemplant instances on Vast.
   - Monitor instances and replace any that fail.
4. Run the fibonacci example program, which will:
   - Generate a fibonacci computation proof request.
   - Submit the request to Hierophant.
   - Wait for a Contemplant to pick up the work and generate a proof.
   - Retrieve and verify the completed proof.

The fibonacci example demonstrates the complete proof generation pipeline. You can watch the logs to see the proof request, witness generation, proof generation on GPU, and final verification.

### Managing Services

To start services in detached mode, run `make scriptory-d`. To view logs from all services, run `make logs`. To check service status, run `make status`. To stop all services, run `make stop`. To restart services, run `make restart`.

Additional targets are available for building images, running tests, and cleaning up resources. Run `make help` for a complete list of available commands.

## Architecture

Scriptory orchestrates three core components:

- **Hierophant**: The prover network coordinator that manages proof requests, worker registration, and artifact storage. Clients submit proof requests to Hierophant and retrieve completed proofs.
- **Magister**: The Vast instance manager that automatically creates, monitors, and maintains Contemplant workers on GPU instances. Magister ensures the configured number of instances are always available.
- **Contemplant**: GPU-accelerated proof generation workers that connect to Hierophant via WebSocket, receive proof tasks, and generate zkVM proofs using CUDA acceleration.

## Requirements

- Docker and Docker Compose
- A Vast.ai account with API key.
- A publicly accessible IP address or hostname (for Contemplants to connect back to).
- Network ports 9000, 9010, and 8555 accessible (or configured differently in `.env`). You must make sure that the Vast template you are using exposes the necessary Contemplant ports.

# Security

If you discover any bug; flaw; issue; dæmonic incursion; or other malicious, negligent, or incompetent action that impacts the security of any of these projects please responsibly disclose them to us; instructions are available [here](./SECURITY.md).

# License

The [license](./LICENSE) for all of our original work is `LicenseRef-VPL WITH AGPL-3.0-only`. This includes every asset in this repository: code, documentation, images, branding, and more. You are licensed to use all of it so long as you maintain _maximum possible virality_ and our copyleft licenses.

Permissive open source licenses are tools for the corporate subversion of libre software; visible source licenses are an even more malignant scourge. All original works in this project are to be licensed under the most aggressive, virulently-contagious copyleft terms possible. To that end everything is licensed under the [Viral Public License](./licenses/LicenseRef-VPL) coupled with the [GNU Affero General Public License v3.0](./licenses/AGPL-3.0-only) for use in the event that some unaligned party attempts to weasel their way out of copyleft protections. In short: if you use or modify anything in this project for any reason, your project must be licensed under these same terms.

For art assets specifically, in case you want to further split hairs or attempt to weasel out of this virality, we explicitly license those under the viral and copyleft [Free Art License 1.3](./licenses/FreeArtLicense-1.3).
