// deploy/00_deploy_lex_amoris.js
//
// Deployment script for the Euystacio Framework smart contracts on Optimism.
//
// Deployment order:
//   1. LexAmorisWhitelist  — ERC-165 whitelist (Lex Amoris law)
//   2. SilentBridge        — payload conduit (queries whitelist)
//   3. VitalTrust          — signature verifier (queries whitelist)
//   4. AUFHOR              — authorship registry (queries whitelist)
//   5. NexusCore           — central coordinator (links all above)
//
// Usage (Hardhat):
//   npx hardhat run scripts/deploy.js --network optimism
//
// After deployment verify on Etherscan / Optimistic-Etherscan:
//   npx hardhat verify --network optimism <LexAmorisWhitelist address> <owner>
//   npx hardhat verify --network optimism <SilentBridge address> <whitelist> <owner>
//   npx hardhat verify --network optimism <VitalTrust address>   <whitelist> <owner>
//   npx hardhat verify --network optimism <AUFHOR address>       <whitelist> <owner>
//   npx hardhat verify --network optimism <NexusCore address>    <whitelist> <silentBridge> <vitalTrust> <aufhor> <owner>

const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying Euystacio Framework contracts with account:", deployer.address);

  // ── 1. LexAmorisWhitelist ───────────────────────────────────────────────────
  const LexAmorisWhitelist = await ethers.getContractFactory("LexAmorisWhitelist");
  const whitelist = await LexAmorisWhitelist.deploy(deployer.address);
  await whitelist.waitForDeployment();
  console.log("LexAmorisWhitelist deployed to:", await whitelist.getAddress());

  // ── 2. SilentBridge ────────────────────────────────────────────────────────
  const SilentBridge = await ethers.getContractFactory("SilentBridge");
  const silentBridge = await SilentBridge.deploy(
    await whitelist.getAddress(),
    deployer.address
  );
  await silentBridge.waitForDeployment();
  console.log("SilentBridge deployed to:", await silentBridge.getAddress());

  // ── 3. VitalTrust ──────────────────────────────────────────────────────────
  const VitalTrust = await ethers.getContractFactory("VitalTrust");
  const vitalTrust = await VitalTrust.deploy(
    await whitelist.getAddress(),
    deployer.address
  );
  await vitalTrust.waitForDeployment();
  console.log("VitalTrust deployed to:", await vitalTrust.getAddress());

  // ── 4. AUFHOR ──────────────────────────────────────────────────────────────
  const AUFHOR = await ethers.getContractFactory("AUFHOR");
  const aufhor = await AUFHOR.deploy(
    await whitelist.getAddress(),
    deployer.address
  );
  await aufhor.waitForDeployment();
  console.log("AUFHOR deployed to:", await aufhor.getAddress());

  // ── 5. NexusCore ───────────────────────────────────────────────────────────
  const NexusCore = await ethers.getContractFactory("NexusCore");
  const nexusCore = await NexusCore.deploy(
    await whitelist.getAddress(),
    await silentBridge.getAddress(),
    await vitalTrust.getAddress(),
    await aufhor.getAddress(),
    deployer.address
  );
  await nexusCore.waitForDeployment();
  console.log("NexusCore deployed to:", await nexusCore.getAddress());

  console.log("\n=== Deployment Summary ===");
  console.log("LexAmorisWhitelist :", await whitelist.getAddress());
  console.log("SilentBridge       :", await silentBridge.getAddress());
  console.log("VitalTrust         :", await vitalTrust.getAddress());
  console.log("AUFHOR             :", await aufhor.getAddress());
  console.log("NexusCore          :", await nexusCore.getAddress());
  console.log("Seedbringer        :", deployer.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
