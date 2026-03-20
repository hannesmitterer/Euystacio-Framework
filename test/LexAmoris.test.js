// test/LexAmoris.test.js
// Hardhat/Mocha tests for the Lex Amoris Whitelist and connected contracts.
// Run: npx hardhat test

const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("LexAmorisWhitelist", function () {
  let whitelist, owner, alice, bob;

  beforeEach(async function () {
    [owner, alice, bob] = await ethers.getSigners();
    const LexAmorisWhitelist = await ethers.getContractFactory("LexAmorisWhitelist");
    whitelist = await LexAmorisWhitelist.deploy(owner.address);
    await whitelist.waitForDeployment();
  });

  it("supports ERC-165 interface", async function () {
    // ERC-165 interfaceId
    expect(await whitelist.supportsInterface("0x01ffc9a7")).to.equal(true);
  });

  it("supports ILexAmorisWhitelist interface", async function () {
    const iface = new ethers.Interface([
      "function isAllowed(address) external view returns (bool)",
      "function isTermAllowed(address,string) external view returns (bool)",
    ]);
    const id =
      BigInt(iface.getFunction("isAllowed").selector) ^
      BigInt(iface.getFunction("isTermAllowed").selector);
    const interfaceId = "0x" + id.toString(16).padStart(8, "0");
    expect(await whitelist.supportsInterface(interfaceId)).to.equal(true);
  });

  it("returns false for unapproved address", async function () {
    expect(await whitelist.isAllowed(alice.address)).to.equal(false);
  });

  it("owner can approve and revoke an address", async function () {
    await whitelist.approve(alice.address);
    expect(await whitelist.isAllowed(alice.address)).to.equal(true);

    await whitelist.revoke(alice.address);
    expect(await whitelist.isAllowed(alice.address)).to.equal(false);
  });

  it("owner can approve and revoke a term", async function () {
    await whitelist.approveTerm(alice.address, "PAYLOAD");
    expect(await whitelist.isTermAllowed(alice.address, "PAYLOAD")).to.equal(true);

    await whitelist.revokeTerm(alice.address, "PAYLOAD");
    expect(await whitelist.isTermAllowed(alice.address, "PAYLOAD")).to.equal(false);
  });

  it("non-owner cannot approve", async function () {
    await expect(
      whitelist.connect(alice).approve(bob.address)
    ).to.be.revertedWithCustomError(whitelist, "OwnableUnauthorizedAccount");
  });

  it("batchApprove whitelists multiple addresses", async function () {
    await whitelist.batchApprove([alice.address, bob.address]);
    expect(await whitelist.isAllowed(alice.address)).to.equal(true);
    expect(await whitelist.isAllowed(bob.address)).to.equal(true);
  });

  it("batchRevoke removes multiple addresses", async function () {
    await whitelist.batchApprove([alice.address, bob.address]);
    await whitelist.batchRevoke([alice.address, bob.address]);
    expect(await whitelist.isAllowed(alice.address)).to.equal(false);
    expect(await whitelist.isAllowed(bob.address)).to.equal(false);
  });
});

describe("SilentBridge", function () {
  let whitelist, bridge, owner, alice;

  beforeEach(async function () {
    [owner, alice] = await ethers.getSigners();
    const LexAmorisWhitelist = await ethers.getContractFactory("LexAmorisWhitelist");
    whitelist = await LexAmorisWhitelist.deploy(owner.address);

    const SilentBridge = await ethers.getContractFactory("SilentBridge");
    bridge = await SilentBridge.deploy(
      await whitelist.getAddress(),
      owner.address
    );
  });

  it("rejects payload from non-whitelisted sender", async function () {
    const payload = ethers.toUtf8Bytes("hello nexus");
    await expect(
      bridge.connect(alice).transmitPayload(payload)
    ).to.be.revertedWith("SilentBridge: sender not approved by Lex Amoris");
  });

  it("accepts payload from whitelisted sender", async function () {
    await whitelist.approve(alice.address);
    const payload = ethers.toUtf8Bytes("hello nexus");
    await expect(bridge.connect(alice).transmitPayload(payload)).to.emit(
      bridge,
      "PayloadTransmitted"
    );
  });

  it("rejects term payload when term not approved", async function () {
    await whitelist.approve(alice.address);
    const payload = ethers.toUtf8Bytes("data");
    await expect(
      bridge.connect(alice).transmitPayloadForTerm(payload, "PAYLOAD")
    ).to.be.revertedWith("SilentBridge: term not approved by Lex Amoris");
  });

  it("accepts term payload when both global and term are approved", async function () {
    await whitelist.approve(alice.address);
    await whitelist.approveTerm(alice.address, "PAYLOAD");
    const payload = ethers.toUtf8Bytes("data");
    await expect(
      bridge.connect(alice).transmitPayloadForTerm(payload, "PAYLOAD")
    ).to.emit(bridge, "PayloadTransmitted");
  });
});

describe("VitalTrust", function () {
  let whitelist, trust, owner, alice;

  beforeEach(async function () {
    [owner, alice] = await ethers.getSigners();
    const LexAmorisWhitelist = await ethers.getContractFactory("LexAmorisWhitelist");
    whitelist = await LexAmorisWhitelist.deploy(owner.address);

    const VitalTrust = await ethers.getContractFactory("VitalTrust");
    trust = await VitalTrust.deploy(await whitelist.getAddress(), owner.address);
  });

  it("rejects signature from non-whitelisted signer", async function () {
    const message = ethers.toUtf8Bytes("test message");
    const sig = await alice.signMessage(message);
    await expect(
      trust.verifySignature(message, ethers.getBytes(sig))
    ).to.be.revertedWith("VitalTrust: signer not approved by Lex Amoris");
  });

  it("accepts signature from whitelisted signer", async function () {
    await whitelist.approve(alice.address);
    const message = ethers.toUtf8Bytes("test message");
    const sig = await alice.signMessage(message);
    await expect(
      trust.verifySignature(message, ethers.getBytes(sig))
    ).to.emit(trust, "SignatureAccepted");
  });
});

describe("AUFHOR", function () {
  let whitelist, aufhor, owner, alice;

  beforeEach(async function () {
    [owner, alice] = await ethers.getSigners();
    const LexAmorisWhitelist = await ethers.getContractFactory("LexAmorisWhitelist");
    whitelist = await LexAmorisWhitelist.deploy(owner.address);

    const AUFHOR = await ethers.getContractFactory("AUFHOR");
    aufhor = await AUFHOR.deploy(await whitelist.getAddress(), owner.address);
  });

  it("rejects authorship registration from non-whitelisted sender", async function () {
    const payload = ethers.toUtf8Bytes("content");
    await expect(
      aufhor.connect(alice).registerAuthorship(payload)
    ).to.be.revertedWith("AUFHOR: sender not approved by Lex Amoris");
  });

  it("registers authorship for whitelisted sender", async function () {
    await whitelist.approve(alice.address);
    const payload = ethers.toUtf8Bytes("content");
    await expect(
      aufhor.connect(alice).registerAuthorship(payload)
    ).to.emit(aufhor, "AuthorshipRegistered");
  });

  it("confirms isAuthor after registration", async function () {
    await whitelist.approve(alice.address);
    const payload = ethers.toUtf8Bytes("unique content xyz");
    await aufhor.connect(alice).registerAuthorship(payload);
    const contentHash = ethers.keccak256(payload);
    expect(await aufhor.isAuthor(contentHash, alice.address)).to.equal(true);
  });
});

describe("NexusCore", function () {
  let whitelist, bridge, trust, aufhorContract, nexus, owner, alice;

  beforeEach(async function () {
    [owner, alice] = await ethers.getSigners();

    const LexAmorisWhitelist = await ethers.getContractFactory("LexAmorisWhitelist");
    whitelist = await LexAmorisWhitelist.deploy(owner.address);

    const SilentBridge = await ethers.getContractFactory("SilentBridge");
    bridge = await SilentBridge.deploy(await whitelist.getAddress(), owner.address);

    const VitalTrust = await ethers.getContractFactory("VitalTrust");
    trust = await VitalTrust.deploy(await whitelist.getAddress(), owner.address);

    const AUFHOR = await ethers.getContractFactory("AUFHOR");
    aufhorContract = await AUFHOR.deploy(await whitelist.getAddress(), owner.address);

    const NexusCore = await ethers.getContractFactory("NexusCore");
    nexus = await NexusCore.deploy(
      await whitelist.getAddress(),
      await bridge.getAddress(),
      await trust.getAddress(),
      await aufhorContract.getAddress(),
      owner.address
    );
  });

  it("sets seedbringer to deployer", async function () {
    expect(await nexus.seedbringer()).to.equal(owner.address);
    expect(await nexus.isSeedbringer(owner.address)).to.equal(true);
    expect(await nexus.isSeedbringer(alice.address)).to.equal(false);
  });

  it("verifyConcordance returns false for non-whitelisted address", async function () {
    await expect(nexus.verifyConcordance(alice.address)).to.emit(
      nexus,
      "DivergenceDetected"
    );
  });

  it("verifyConcordance returns true for whitelisted address", async function () {
    await whitelist.approve(alice.address);
    await expect(nexus.verifyConcordance(alice.address)).to.emit(
      nexus,
      "ConcordanceAchieved"
    );
  });

  it("applyPhiNexus returns true for stable actions", async function () {
    const stable = ethers.toUtf8Bytes("StableAction");
    expect(await nexus.applyPhiNexus(stable)).to.equal(true);
  });

  it("applyPhiNexus returns false for UnstableAction sentinel", async function () {
    const unstable = ethers.toUtf8Bytes("UnstableAction");
    expect(await nexus.applyPhiNexus(unstable)).to.equal(false);
  });
});
