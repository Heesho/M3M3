const { ethers } = require("hardhat");
const { utils, BigNumber } = require("ethers");
const hre = require("hardhat");

/*===================================================================*/
/*===========================  SETTINGS  ============================*/

const BASE_ADDRESS = "0x9c3C9283D3e44854697Cd22D3Faa240Cfb032889"; // BASE Token Address (eg WETH on zkEVM)
const TREASURY_ADDRESS = "0x19858F6c29eA886853dc97D1a68ABf8d4Cb07712"; // Treasury Address

const meme1 = {
  index: 1,
  name: "HenloWorld",
  symbol: "HENLO",
  uri: "https://m.media-amazon.com/images/I/51jctBmVm5L._AC_UF894,1000_QL80_.jpg",
};

const meme2 = {
  index: 2,
  name: "PepeBusiness",
  symbol: "PEPEBIZ",
  uri: "https://www.tbstat.com/cdn-cgi/image/format=webp,q=75/wp/uploads/2023/05/Fvz9hOIXwAEaIR8.jpeg",
};

const meme3 = {
  index: 3,
  name: "Doge in a Taco",
  symbol: "DOGETACO",
  uri: "https://external-preview.redd.it/56OAprDalFy7aI2_Ve2kdFfBPenTYAh23T9PnKktTro.jpg?auto=webp&s=f2687b16f02330117e20931c0e177423519803fc",
};

const meme4 = {
  index: 4,
  name: "Cat Wif Hat",
  symbol: "CWH",
  uri: "https://i.etsystatic.com/18460845/r/il/d7df20/3538227185/il_fullxfull.3538227185_lotd.jpg",
};

const meme5 = {
  index: 5,
  name: "Conspiracies",
  symbol: "CHARLIE",
  uri: "https://i.kym-cdn.com/entries/icons/original/000/022/524/pepe_silvia_meme_banner.jpg",
};

const meme6 = {
  index: 6,
  name: "LilGuy",
  symbol: "HAMSTER",
  uri: "https://i.kym-cdn.com/news_feeds/icons/mobile/000/035/373/c98.jpg",
};

const meme7 = {
  index: 7,
  name: "Shrek Knows Something We Don't",
  symbol: "SHREK",
  uri: "https://snworksceo.imgix.net/dth/84e832cc-b853-40d1-bcf9-bd0d2aae2bec.sized-1000x1000.png?w=800&h=600",
};

const meme8 = {
  index: 8,
  name: "CarSalesman",
  symbol: "CARS",
  uri: "https://helios-i.mashable.com/imagery/articles/068tGOwxBzz2IjPMTXee8SH/hero-image.fill.size_1200x900.v1614270504.jpg",
};

/*===========================  END SETTINGS  ========================*/
/*===================================================================*/

// Constants
const sleep = (delay) => new Promise((resolve) => setTimeout(resolve, delay));
const convert = (amount, decimals) => ethers.utils.parseUnits(amount, decimals);

// Contract Variables
let factory, multicall, router;
let meme;

/*===================================================================*/
/*===========================  CONTRACT DATA  =======================*/

async function getContracts() {
  factory = await ethers.getContractAt(
    "contracts/MemeFactory.sol:MemeFactory",
    "0xb903FB333701f6F2f40045a0F5DC0ffcb095db59"
  );
  multicall = await ethers.getContractAt(
    "contracts/MemeMulticall.sol:MemeMulticall",
    "0xD227516CB3D3097bc4B1859ff283fbe437Ca986a"
  );
  router = await ethers.getContractAt(
    "contracts/MemeRouter.sol:MemeRouter",
    "0xC2972700E071ad08DDB1cD3fd16F17b3762De066"
  );

  // meme = await ethers.getContractAt(
  //   "contracts/Meme.sol:Meme",
  //   "0xA843BBCD7f5770A64C2A052759fb2a97267EF955"
  // );

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
  await router.createMeme(meme8.name, meme8.symbol, meme8.uri, {
    value: ethers.utils.parseEther("0.1"),
    gasPrice: ethers.gasPrice,
  });
  meme = await factory.getMemeByIndex(meme8.index);
  await sleep(5000);
  console.log("Meme Deployed at:", meme.address);
}

async function verifyMeme() {
  console.log("Starting Meme Verification");
  await hre.run("verify:verify", {
    address: meme.address,
    contract: "contracts/Meme.sol:Meme",
    constructorArguments: [meme1.name, meme1.symbol, meme1.uri, BASE_ADDRESS],
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

  // console.log("Starting System Deployment");
  // await deployFactory();
  // await deployMulticall();
  // await deployRouter();
  // await printDeployment();

  /*********** UPDATE getContracts() with new addresses *************/

  //===================================================================
  // 2. Verify System
  //===================================================================

  // console.log("Starting System Verificatrion Deployment");
  // await verifyFactory();
  await verifyMulticall();
  // await verifyRouter();

  //===================================================================
  // 3. Deploy Meme
  //===================================================================

  // console.log("Starting Meme Delpoyment");
  // await deployMeme();
  // console.log("Meme Deployed");

  //===================================================================
  // 4. Verify Meme
  //===================================================================

  // console.log("Starting Meme Verification");
  // await verifyMeme();
  // console.log("Meme Verified");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
