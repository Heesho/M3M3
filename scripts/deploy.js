const { ethers } = require("hardhat");
const { utils, BigNumber } = require("ethers");
const hre = require("hardhat");

/*===================================================================*/
/*===========================  SETTINGS  ============================*/

const BASE_ADDRESS = "0x0000000000000000000000000000000000000000"; // BASE Token Address (eg WETH on zkEVM)
const TREASURY_ADDRESS = "0x0000000000000000000000000000000000000000"; // Treasury Address

// Meme Key
const INDEX = 1;
const NAME = "Meme 1";
const SYMBOL = "MEME1";
const URI = "https://ipfs.io/meme1";

/*===========================  END SETTINGS  ========================*/
/*===================================================================*/

// Constants
const sleep = (delay) => new Promise((resolve) => setTimeout(resolve, delay));
const convert = (amount, decimals) => ethers.utils.parseUnits(amount, decimals);

// Contract Variables
let factory, multicall, router;

/*===================================================================*/
/*===========================  CONTRACT DATA  =======================*/

async function getContracts() {
  // factory = await ethers.getContractAt("contracts/MemeFactory.sol:MemeFactory", "0x0000000000000000000000000000000000000000");
  // router = await ethers.getContractAt("contracts/MemeRouter.sol:MemeRouter", "0x0000000000000000000000000000000000000000");
  // multicall = await ethers.getContractAt("contracts/MemeMulticall.sol:MemeMulticall", "0x0000000000000000000000000000000000000000");

  // meme = await ethers.getContractAt("contracts/Meme.sol:Meme", "0x0000000000000000000000000000000000000000");

  console.log("Contracts Retrieved");
}

/*===========================  END CONTRACT DATA  ===================*/
/*===================================================================*/

async function deployFactory() {
  console.log("Starting MemeFactory Deployment");
  const factoryArtifact = await ethers.getContractFactory("MemeFactory");
  const factoryContract = await factoryArtifact.deploy(
    BASE_ADDRESS,
    TREASURY_ADDRESS,
    {
      gasPrice: ethers.gasPrice,
    }
  );
  factory = await factoryContract.deployed();
  await sleep(5000);
  console.log("Factory Deployed at:", factory.address);
}

async function deployMulticall() {
  console.log("Starting MemeMulticall Deployment");
  const multicallArtifact = await ethers.getContractFactory("MemeMulticall");
  const multicallContract = await multicallArtifact.deploy(
    factory.address,
    BASE_ADDRESS,
    {
      gasPrice: ethers.gasPrice,
    }
  );
  multicall = await multicallContract.deployed();
  await sleep(5000);
  console.log("Multicall Deployed at:", multicall.address);
}

async function deployRouter() {
  console.log("Starting MemeRouter Deployment");
  const routerArtifact = await ethers.getContractFactory("MemeRouter");
  const routerContract = await routerArtifact.deploy(
    factory.address,
    BASE_ADDRESS,
    {
      gasPrice: ethers.gasPrice,
    }
  );
  router = await routerContract.deployed();
  await sleep(5000);
  console.log("Router Deployed at:", router.address);
}

async function printDeployment() {
  console.log("**************************************************************");
  console.log("Factory: ", factory.address);
  console.log("Multicall: ", multicall.address);
  console.log("Router: ", router.address);
  console.log("**************************************************************");
}

async function verifyFactory() {
  console.log("Starting Factory Verification");
  await hre.run("verify:verify", {
    address: factory.address,
    contract: "contracts/MemeFactory.sol:MemeFactory",
    constructorArguments: [BASE_ADDRESS, TREASURY_ADDRESS],
  });
  console.log("Factory Verified");
}

async function verifyMulticall() {
  console.log("Starting Multicall Verification");
  await hre.run("verify:verify", {
    address: multicall.address,
    contract: "contracts/MemeMulticall.sol:MemeMulticall",
    constructorArguments: [factory.address, BASE_ADDRESS],
  });
  console.log("Multicall Verified");
}

async function verifyRouter() {
  console.log("Starting Router Verification");
  await hre.run("verify:verify", {
    address: router.address,
    contract: "contracts/MemeRouter.sol:MemeRouter",
    constructorArguments: [factory.address, BASE_ADDRESS],
  });
  console.log("Router Verified");
}

async function deployMeme() {
  console.log("Starting Meme Deployment");
  await router.createMeme(NAME, SYMBOL, URI, {
    value: ethers.utils.parseEther("0.1"),
    gasPrice: ethers.gasPrice,
  });
  meme = await factory.getMemeByIndex(INDEX);
  await sleep(5000);
  console.log("Meme Deployed at:", meme.address);
}

async function verifyMeme() {
  console.log("Starting Meme Verification");
  await hre.run("verify:verify", {
    address: meme.address,
    contract: "contracts/Meme.sol:Meme",
    constructorArguments: [NAME, SYMBOL, URI, BASE_ADDRESS],
  });
  console.log("Meme Verified");
}

async function main() {
  const [wallet] = await ethers.getSigners();
  console.log("Using wallet: ", wallet.address);

  await getContracts();

  //===================================================================
  // 1. Deploy System
  //===================================================================

  // console.log('Starting System Deployment');
  // await deployFactory();
  // await deployMulicall();
  // await deployRouter();
  // await printDeployment();

  /*********** UPDATE getContracts() with new addresses *************/

  //===================================================================
  // 2. Verify System
  //===================================================================

  // console.log('Starting System Verificatrion Deployment');
  // await verifyFactory();
  // await verifyMulticall();
  // await verifyRouter();

  //===================================================================
  // 3. Deploy Meme
  //===================================================================

  // console.log('Starting Meme Delpoyment');
  // await deployMeme();
  // console.log("Meme Deployed")

  //===================================================================
  // 4. Verify Meme
  //===================================================================

  // console.log('Starting Meme Verification');
  // await verifyMeme();
  // console.log("Meme Verified");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
