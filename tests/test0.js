const convert = (amount, decimals) => ethers.utils.parseUnits(amount, decimals);
const divDec = (amount, decimals = 18) => amount / 10 ** decimals;
const divDec6 = (amount, decimals = 6) => amount / 10 ** decimals;
const { expect } = require("chai");
const { ethers, network } = require("hardhat");
const { execPath } = require("process");

const AddressZero = "0x0000000000000000000000000000000000000000";
const one = convert("1", 18);
const two = convert("2", 18);
const three = convert("3", 18);
const five = convert("5", 18);
const ten = convert("10", 18);
const twenty = convert("20", 18);
const eighty = convert("80", 18);
const ninety = convert("90", 18);
const oneHundred = convert("100", 18);
const twoHundred = convert("200", 18);
const fiveHundred = convert("500", 18);
const sixHundred = convert("600", 18);
const eightHundred = convert("800", 18);
const oneThousand = convert("1000", 18);
const fourThousand = convert("4000", 18);
const tenThousand = convert("10000", 18);
const oneHundredThousand = convert("100000", 18);

let owner, multisig, treasury, user0, user1, user2;
let memeFactory, meme0, meme1, meme2;
let multicall, router;
let base;

describe("local: test0", function () {
  before("Initial set up", async function () {
    console.log("Begin Initialization");

    [owner, multisig, treasury, user0, user1, user2] =
      await ethers.getSigners();

    const baseArtifact = await ethers.getContractFactory("Base");
    base = await baseArtifact.deploy();
    console.log("- BASE Initialized");

    const memeFactoryArtifact = await ethers.getContractFactory("MemeFactory");
    memeFactory = await memeFactoryArtifact.deploy(
      base.address,
      treasury.address
    );
    console.log("- MemeFactory Initialized");

    const multicallArtifact = await ethers.getContractFactory("MemeMulticall");
    multicall = await multicallArtifact.deploy(
      memeFactory.address,
      base.address
    );
    console.log("- Multicall Initialized");

    const routerArtifact = await ethers.getContractFactory("MemeRouter");
    router = await routerArtifact.deploy(memeFactory.address, base.address);
    console.log("- Router Initialized");

    console.log("- System set up");

    console.log("Initialization Complete");
    console.log();
  });

  it("User0 creates meme0", async function () {
    console.log("******************************************************");
    await router
      .connect(user0)
      .createMeme("Meme 0", "MEME0", "http/ipfs.com", { value: one });
    meme0 = await ethers.getContractAt("Meme", await memeFactory.index_Meme(1));
    console.log("Meme0 Created");
  });

  // it("User0 creates meme0", async function () {
  //   console.log("******************************************************");
  //   await router
  //     .connect(user0)
  //     .createMeme("Meme 1", "MEME1", "http/ipfs.com", { value: one });
  //   meme1 = await ethers.getContractAt("Meme", await memeFactory.index_Meme(2));
  //   console.log("Meme1 Created");
  // });

  // it("User0 buys meme0", async function () {
  //   console.log("******************************************************");
  //   await router.connect(user0).buy(meme0.address, AddressZero, 0, 1904422437, {
  //     value: ten,
  //   });
  // });

  // it("User0 sells meme0", async function () {
  //   console.log("******************************************************");
  //   await meme0.connect(user0).approve(router.address, oneHundred);
  //   await router.connect(user0).sell(meme0.address, oneHundred, 0, 1904422437);
  // });

  // it("User0 sells meme0", async function () {
  //   console.log("******************************************************");
  //   await meme0.connect(user0).approve(router.address, oneHundred);
  //   await router.connect(user0).sell(meme0.address, oneHundred, 0, 1904422437);
  // });

  // it("User0 buys meme0", async function () {
  //   console.log("******************************************************");
  //   await router.connect(user0).buy(meme0.address, AddressZero, 0, 1904422437, {
  //     value: ten,
  //   });
  // });

  // it("User0 buys meme0", async function () {
  //   console.log("******************************************************");
  //   await router.connect(user0).buy(meme0.address, AddressZero, 0, 1904422437, {
  //     value: ten,
  //   });
  // });

  // it("User0 transfers meme0", async function () {
  //   console.log("******************************************************");
  //   await meme0
  //     .connect(user0)
  //     .transfer(user1.address, await meme0.balanceOf(user0.address));
  //   await meme0
  //     .connect(user1)
  //     .transfer(user0.address, await meme0.balanceOf(user1.address));
  // });

  // it("User0 sells meme0", async function () {
  //   console.log("******************************************************");
  //   await meme0.connect(user0).approve(router.address, oneHundredThousand);
  //   await router
  //     .connect(user0)
  //     .sell(meme0.address, oneHundredThousand, 0, 1904422437);
  // });

  // it("User0 sells meme0", async function () {
  //   console.log("******************************************************");
  //   await meme0.connect(user0).approve(router.address, oneHundredThousand);
  //   await router
  //     .connect(user0)
  //     .sell(meme0.address, oneHundredThousand, 0, 1904422437);
  // });

  // it("User0 sells meme0", async function () {
  //   console.log("******************************************************");
  //   await meme0.connect(user0).approve(router.address, tenThousand);
  //   await router.connect(user0).sell(meme0.address, tenThousand, 0, 1904422437);
  // });

  // it("User0 sells meme0", async function () {
  //   console.log("******************************************************");
  //   await meme0.connect(user0).approve(router.address, tenThousand);
  //   await router.connect(user0).sell(meme0.address, tenThousand, 0, 1904422437);
  // });

  // it("User0 sells meme0", async function () {
  //   console.log("******************************************************");
  //   await meme0.connect(user0).approve(router.address, tenThousand);
  //   await router.connect(user0).sell(meme0.address, tenThousand, 0, 1904422437);
  // });

  // it("User0 sells meme0", async function () {
  //   console.log("******************************************************");
  //   await meme0.connect(user0).approve(router.address, fourThousand);
  //   await router
  //     .connect(user0)
  //     .sell(meme0.address, fourThousand, 0, 1904422437);
  // });

  // it("User0 sells meme0", async function () {
  //   console.log("******************************************************");
  //   await meme0.connect(user0).approve(router.address, sixHundred);
  //   await router.connect(user0).sell(meme0.address, sixHundred, 0, 1904422437);
  // });

  // it("User0 sells meme0", async function () {
  //   console.log("******************************************************");
  //   await meme0.connect(user0).approve(router.address, eighty);
  //   await router.connect(user0).sell(meme0.address, eighty, 0, 1904422437);
  // });

  // it("User0 sells meme0", async function () {
  //   console.log("******************************************************");
  //   await meme0.connect(user0).approve(router.address, three);
  //   await router.connect(user0).sell(meme0.address, three, 0, 1904422437);
  // });

  it("User0 buys meme0", async function () {
    console.log("******************************************************");
    await router.connect(user0).buy(meme0.address, AddressZero, 0, 1904422437, {
      value: ten,
    });
  });

  it("User0 sells meme0", async function () {
    console.log("******************************************************");
    await meme0
      .connect(user0)
      .approve(
        router.address,
        (await meme0.balanceOf(user0.address)).sub(oneThousand)
      );
    await router
      .connect(user0)
      .sell(
        meme0.address,
        (await meme0.balanceOf(user0.address)).sub(oneThousand),
        0,
        1904422437
      );
  });

  it("User0 buys meme0", async function () {
    console.log("******************************************************");
    await router.connect(user0).buy(meme0.address, AddressZero, 0, 1904422437, {
      value: ten,
    });
  });

  it("User0 sells meme0", async function () {
    console.log("******************************************************");
    await meme0
      .connect(user0)
      .approve(router.address, await meme0.balanceOf(user0.address));
    await router
      .connect(user0)
      .sell(meme0.address, await meme0.balanceOf(user0.address), 0, 1904422437);
  });

  it("User0 buys meme0", async function () {
    console.log("******************************************************");
    await router.connect(user0).buy(meme0.address, AddressZero, 0, 1904422437, {
      value: oneThousand,
    });
  });

  it("User1 buys meme0", async function () {
    console.log("******************************************************");
    await router
      .connect(user1)
      .buy(meme0.address, user0.address, 0, 1904422437, {
        value: oneThousand,
      });
  });

  it("User0 claims meme0 fees", async function () {
    console.log("******************************************************");
    await meme0;
    await router.connect(user0).claimFees([meme0.address]);
  });

  it("User0 buys meme0", async function () {
    console.log("******************************************************");
    await router.connect(user0).buy(meme0.address, AddressZero, 0, 1904422437, {
      value: ten,
    });
  });

  it("User1 buys meme0", async function () {
    console.log("******************************************************");
    await router.connect(user1).buy(meme0.address, AddressZero, 0, 1904422437, {
      value: ten,
    });
  });

  it("User1 sells meme0", async function () {
    console.log("******************************************************");
    await meme0
      .connect(user1)
      .approve(router.address, await meme0.balanceOf(user1.address));
    await router
      .connect(user1)
      .sell(meme0.address, await meme0.balanceOf(user1.address), 0, 1904422437);
  });

  it("User0 claims meme0 fees", async function () {
    console.log("******************************************************");
    await meme0;
    await router.connect(user0).claimFees([meme0.address]);
  });

  it("User1 claims meme0 fees", async function () {
    console.log("******************************************************");
    await meme0;
    await router.connect(user1).claimFees([meme0.address]);
  });

  it("User0 updates status through meme contract", async function () {
    console.log("******************************************************");
    await meme0.connect(user0).updateStatus("What in the world is going on?");
  });

  it("User0 updates status through router", async function () {
    console.log("******************************************************");
    await meme0.connect(user0).approve(router.address, ten);
    await router.connect(user0).updateStatus(meme0.address, "Sup everybody?");
  });

  it("Meme0, user0", async function () {
    console.log("******************************************************");
    let res = await multicall.getMemeData(1, user0.address);
    console.log("ADDRESS: ", res[0]);
    console.log("NAME: ", res[1]);
    console.log("SYMBOL: ", res[2]);
    console.log();
    console.log("URL: ", res[3]);
    console.log("Status: ", res[4]);
    console.log();
    console.log("Reserve Virtual BASE: ", divDec(res[5]));
    console.log("Reserve Real BASE: ", divDec(res[6]));
    console.log("Reserve Real MEME: ", divDec(res[7]));
    console.log("Max Supply: ", divDec(res[8]));
    console.log();
    console.log(
      "Bonding Curve Base Balance: ",
      divDec(await base.balanceOf(meme0.address))
    );
    console.log(
      "Bonding Curve Meme Balance: ",
      divDec(await meme0.balanceOf(meme0.address))
    );
    console.log(
      "Fees Base Balance: ",
      divDec(await base.balanceOf(await meme0.fees()))
    );
    console.log();
    console.log("Floor Price: ", divDec(res[9]));
    console.log("Market Price: ", divDec(res[10]));
    console.log("TVL: ", divDec(res[11]));
    console.log("Total Fees BASE: ", divDec(res[12]));
    console.log();
    console.log("Account Native: ", divDec(res[13]));
    console.log("Account BASE: ", divDec(res[14]));
    console.log("Account MEME: ", divDec(res[15]));
    console.log("Account Claimable BASE: ", divDec(res[16]));
  });

  it("Quote Buy In", async function () {
    console.log("******************************************************");
    let res = await multicall
      .connect(owner)
      .quoteBuyIn(meme0.address, ten, 9800);
    console.log("BASE in", divDec(ten));
    console.log("Slippage Tolerance", "2%");
    console.log();
    console.log("MEME out", divDec(res.output));
    console.log("slippage", divDec(res.slippage));
    console.log("min MEME out", divDec(res.minOutput));
  });

  it("Quote Sell In", async function () {
    console.log("******************************************************");
    let res = await multicall.quoteSellIn(
      meme0.address,
      await meme0.balanceOf(user0.address),
      9700
    );
    console.log("MEME in", divDec(await meme0.balanceOf(user0.address)));
    console.log("Slippage Tolerance", "3%");
    console.log();
    console.log("BASE out", divDec(res.output));
    console.log("slippage", divDec(res.slippage));
    console.log("min BASE out", divDec(res.minOutput));
  });

  it("Quote buy out", async function () {
    console.log("******************************************************");
    let res = await multicall
      .connect(owner)
      .quoteBuyOut(meme0.address, ten, 9700);
    console.log("MEME out", divDec(ten));
    console.log("Slippage Tolerance", "3%");
    console.log();
    console.log("BASE in", divDec(res.output));
    console.log("slippage", divDec(res.slippage));
    console.log("min MEME out", divDec(res.minOutput));
  });

  it("Quote sell out", async function () {
    console.log("******************************************************");
    let res = await multicall
      .connect(owner)
      .quoteSellOut(meme0.address, five, 9950);
    console.log("BASE out", divDec(five));
    console.log("Slippage Tolerance", "0.5%");
    console.log();
    console.log("MEME in", divDec(res.output));
    console.log("slippage", divDec(res.slippage));
    console.log("min BASE out", divDec(res.minOutput));
  });
});
