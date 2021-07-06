const { expectRevert, expectEvent, BN, time } = require("@openzeppelin/test-helpers");
const { assert } = require("chai");
const web3 = require("web3");

const XCrssToken = artifacts.require('xCrssToken');
const CrssToken = artifacts.require('MockBEP20');

contract('XCrssToken', ([owner, masterChef, userWallet]) => {
    const amountWei = new BN('100');
    const amountGwei = new BN('100000000000');
    const amountEther = new BN('100000000000000000000');

    const amountToMint = new BN('1000');

    // it('only owner', async () => {
    //     // assert.equal(( await this.xcrssToken.owner() ), accounts);
    //     assert.equal(( await this.crssToken.owner() ), owner);
    // });

    describe('Test case with 100 wei', () => {
        before(async () => {
            this.crssToken = await CrssToken.new('CrossWise', 'CRSS', { from: owner });
            this.xcrssToken = await XCrssToken.new({ from: owner });
    
            // mint CRSS token to user and masterChef addresses
            await this.crssToken.mint(masterChef, amountToMint, { from: owner });
            await this.crssToken.mint(userWallet, amountToMint, { from: owner });
    
            // initialize XCRSS token with CRSS address and masterChef address
            await this.xcrssToken.initialize(this.crssToken.address, masterChef, { from: owner });
        });
        
        describe('depositToken function test', () => {
            it('Fail when call with user wallet', async () => {
                await this.crssToken.approve(this.xcrssToken.address, amountWei, { from: masterChef });
                await expectRevert(this.xcrssToken.depositToken(userWallet, amountWei, { from: userWallet }), "xCrssToken.deposit: Sender must be masterChef contract");
            });

            it('Success when call with masterChef', async () => {
                await this.crssToken.approve(this.xcrssToken.address, amountWei, { from: masterChef });

                const receipt = await this.xcrssToken.depositToken(userWallet, amountWei, { from: masterChef });
                await expectEvent(receipt, 'Deposit', { depositUser: userWallet, rewardAmount: amountWei });
            });
        })

        describe('unlockedToken function test', () => {
            it('Expected unlocked amount is 0 when just deposited', async () => {
                assert.equal(( await this.xcrssToken.unlockedToken(userWallet)), 0);
            });

            it('Expected unlocked amount is 40 in two months', async () => {
                await time.increase(time.duration.days(60));
                assert.equal(( await this.xcrssToken.unlockedToken(userWallet)), 40);
            });

            it('Expected unlocked amount is 40 in 70 days', async () => {
                await time.increase(time.duration.days(10));
                assert.equal(( await this.xcrssToken.unlockedToken(userWallet)), 40);
            });
        })

        describe('withdraw function test', () => {
            it('Fail to withdraw with low unlocked token amount', async () => {
                await expectRevert(this.xcrssToken.withdrawToken(50, { from: userWallet }), "xCrssToken.withdrawToken: Not enough token to withdraw.");
            });

            it('Withdraw 30 CRSS', async () => {
                const receipt = await this.xcrssToken.withdrawToken(30, { from: userWallet });
                await expectEvent(receipt, 'WithdrawToken', { user: userWallet, amount: new BN('30') });
            });

            it('Expect left unlocked token amount is 10', async () => {
                await assert.equal(( await this.xcrssToken.unlockedToken(userWallet)), 10);
            })
        })
    })
})