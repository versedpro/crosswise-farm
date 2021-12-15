const { BN, constants, expectEvent, time, expectRevert, ether, balance } = require('@openzeppelin/test-helpers');
const { ZERO_ADDRESS } = constants;

const { expect } = require('chai');

// const AccessControls = artifacts.require('AccessControls');
const ERC20 = artifacts.require('MockBEP20');
const BUSD = artifacts.require('MockBEP20');
// const VestingToken = artifacts.require('VestingToken');
const PreSale = artifacts.require('PreSaleV2');


function seconds_since_epoch(){ 
    var d = new Date();
    return Math.floor( d.getTime() / 1000 ); 
}
  

contract('PreSaleV2 Test', function ([owner, masterWallet, investor1, investor2, investor3]) {

    const name = 'BUSD coin';
    const symbol = 'BUSD';
    const decimal = new BN('18');


    const tokenSupply = new BN('100000000000000000000000000');
    const seed_sale_token = new BN('10000000000000000000000000');
    const TWO_THOUSAND_TOKENS = new BN('2000000000000000000000');
    const ONE_THOUSAND_TOKENS = new BN('1000000000000000000000');
    const ONE_HUNDRED_TOKENS = new BN('100000000000000000000');
    const TEN_TOKEN = new BN('10000000000000000000');
    const FIVE_TOKENS = new BN('5000000000000000000');
    const TWO_TOKENS = new BN('2000000000000000000');
    const ONE_TOKEN = new BN('1000000000000000000');
    const REMAINING_TOKENS = new BN('99000000000000000000');
    const Thirty_days = new BN('2592000');

    before(async function () {
        this.token = await ERC20.new("Crss token", "CRSS", {from: owner});
        this.busdToken = await BUSD.new("BUSD COIN", "BUSD", {from: owner});
        let currentTime = await time.latest();
        this.PreSale = await PreSale.new(this.token.address, this.busdToken.address, masterWallet, new BN(currentTime.add(new BN('1'))) , {from: owner});
        await this.PreSale.setWhiteList(investor1, true, {from: owner});
        await this.PreSale.setWhiteList(investor2, true, {from: owner});
        await this.busdToken.mint(owner, tokenSupply, {from: owner});
        await this.busdToken.transfer(investor1, new BN('400000000000000000000000'), {from:owner});
        await this.busdToken.transfer(investor2, ONE_HUNDRED_TOKENS, {from:owner});
        await this.token.mint(owner, tokenSupply, {from: owner});
        // this.seedSale = await SeedSale.new(this.token.address, this.accessControls.address, this.vestingContract.address, masterWallet, startTime);
    });


    describe.only('buyTokens', function () {
        describe('validate', function() {

            it('revert because depoist amount is over hardcap', async function () {
                await time.increase(new BN('10'));
                let currentTime = await time.latest();
                console.log(currentTime.toString());
                await this.PreSale.updateHardCapAmount( ONE_TOKEN, {from:owner});
                // await this.daiToken.approve(this.PreSale.address, TEN_TOKEN, {from: investor1});
                await expectRevert(this.PreSale.deposit(TEN_TOKEN, {from:investor1}), "deposit is above hardcap limit");
            });

            it('revert because deposit amount is bigger than max deposit amount', async function () {
                await this.PreSale.updateHardCapAmount( tokenSupply, {from:owner});
                await expectRevert(this.PreSale.deposit(TWO_THOUSAND_TOKENS, {from:investor2}), "Presale.deposit: deposit amount is bigger than max deposit amount");
            });

            it('revert because PreSale contract doesnt have enough reward token', async function () {
                await this.token.transfer(this.PreSale.address, ONE_TOKEN, {from: owner});
                await this.busdToken.approve(this.PreSale.address, TEN_TOKEN, {from: investor1});
                await expectRevert(this.PreSale.deposit(TEN_TOKEN, {from:investor1}), "Presale.deposit: not enough token to reward");
            });
        });
        

        describe.only('buyTokens success', async function () {
            before(async function () {
                await this.token.mint(this.PreSale.address, tokenSupply, {from: owner});
            })
            it('buyTokens', async function () {
                const oldBalance = await this.busdToken.balanceOf(masterWallet);
                await this.busdToken.approve(this.PreSale.address, TEN_TOKEN, {from: investor1});
                await this.PreSale.deposit(TEN_TOKEN, {from:investor1});
                const newBalance = await this.busdToken.balanceOf(masterWallet);
                const changes = new BN(newBalance.sub(oldBalance));
                expect(changes).to.be.bignumber.equal('10000000000000000000');
                const userDetail = await this.PreSale.userDetail(investor1);
                expect(userDetail.totalRewardAmount).to.be.bignumber.equal('13333333333333333333');
                expect(userDetail.depositAmount).to.be.bignumber.equal('10000000000000000000');
                expect(userDetail.withdrawAmount).to.be.bignumber.equal('0');
            });
            it('buyTokens by 1st investor again', async function () {
                const oldBalance = await this.busdToken.balanceOf(masterWallet);
                await this.busdToken.approve(this.PreSale.address, TEN_TOKEN, {from: investor1});
                await this.PreSale.deposit(TEN_TOKEN, {from:investor1});
                const newBalance = await this.busdToken.balanceOf(masterWallet);
                const changes = new BN(newBalance.sub(oldBalance));
                expect(changes).to.be.bignumber.equal('10000000000000000000');
                const userDetail = await this.PreSale.userDetail(investor1);
                expect(userDetail.totalRewardAmount).to.be.bignumber.equal('26666666666666666666');
                expect(userDetail.depositAmount).to.be.bignumber.equal('20000000000000000000');
                expect(userDetail.withdrawAmount).to.be.bignumber.equal('0');
            });
            it('buyTokens by 2nd investor (check decimals)', async function () {
                const oldBalance = await this.busdToken.balanceOf(masterWallet);
                await this.busdToken.approve(this.PreSale.address, new BN('12500000000000000000'), {from: investor2});
                await this.PreSale.deposit(new BN('12500000000000000000'), {from:investor2});
                const newBalance = await this.busdToken.balanceOf(masterWallet);
                const changes = new BN(newBalance.sub(oldBalance));
                expect(changes).to.be.bignumber.equal('12500000000000000000');
                const userDetail = await this.PreSale.userDetail(investor2);
                expect(userDetail.totalRewardAmount).to.be.bignumber.equal('16666666666666666666');
                expect(userDetail.depositAmount).to.be.bignumber.equal('12500000000000000000');
                expect(userDetail.withdrawAmount).to.be.bignumber.equal('0');
            });
            it.only('buytokens over softcap amount (check change of token price)', async function () {
                const oldBalance = await this.busdToken.balanceOf(masterWallet);
                await this.PreSale.updateMaxBusdPerWallet(new BN('400000000000000000000000'), {from: owner});
                await this.busdToken.approve(this.PreSale.address, new BN('400000000000000000000000'), {from: investor1});
                await this.PreSale.deposit(new BN('374995000000000000000000'), {from:investor1});
                const newBalance = await this.busdToken.balanceOf(masterWallet);
                const changes = new BN(newBalance.sub(oldBalance));
                expect(changes).to.be.bignumber.equal('374995000000000000000000');
                let userDetail = await this.PreSale.userDetail(investor1);
                expect(userDetail.totalRewardAmount).to.be.bignumber.equal('499993333333333333333333');
                let currentTokenPrice = await this.PreSale.tokenPrice();
                expect(currentTokenPrice).to.be.bignumber.equal('750000000000000000');
                await this.PreSale.deposit(TEN_TOKEN, {from: investor1});
                const latestBalance = await this.busdToken.balanceOf(masterWallet);
                const lastChange = new BN(latestBalance.sub(newBalance));
                expect(lastChange).to.be.bignumber.equal('10000000000000000000');
                currentTokenPrice = await this.PreSale.tokenPrice();
                expect(currentTokenPrice).to.be.bignumber.equal('800000000000000000');
                userDetail = await this.PreSale.userDetail(investor1);
                expect(userDetail.totalRewardAmount).to.be.bignumber.equal('500006249999999999999999');
                expect(userDetail.depositAmount).to.be.bignumber.equal('375005000000000000000000');
                expect(userDetail.withdrawAmount).to.be.bignumber.equal('0');
            });
            
        });
    });

    describe('Claim Token', function () {
        before(async function () {
            await this.token.transfer(this.PreSale.address, ONE_THOUSAND_TOKENS, {from: owner});
            await this.busdToken.approve(this.PreSale.address, ONE_HUNDRED_TOKENS, {from: investor1});
            await this.PreSale.deposit(ONE_HUNDRED_TOKENS, {from:investor1});
        })
        describe('validate', function() {
    
            it('revert because not enough balance to withdraw', async function () {
                await expectRevert(this.PreSale.withdrawToken(TWO_TOKENS, {from:investor1}), "Presale.withdrawToken: Not enough token to withdraw.");
            });
        });
        

        describe('claimTokens success', async function () {
            it('claimTokens', async function () {
                // await time.increase(new BN('10'));
                let rewardAmount = await this.PreSale.unlockedToken(investor1);
                expect(rewardAmount).to.be.bignumber.equal('0');
            });
            it('claimTokens', async function () {
                await time.increase(new BN('2592000'));
                let rewardAmount = await this.PreSale.unlockedToken(investor1);
                expect(rewardAmount).to.be.bignumber.equal('40000000000000000000');
                await this.PreSale.withdrawToken(new BN('40000000000000000000'),{from: investor1});
                const balance = await this.token.balanceOf(investor1);
                expect(balance).to.be.bignumber.equal('40000000000000000000');
                rewardAmount = await this.PreSale.unlockedToken(investor1);
                expect(rewardAmount).to.be.bignumber.equal('0');
                const userDetail = await this.PreSale.userDetail(investor1);
                expect(userDetail.totalRewardAmount).to.be.bignumber.equal('200000000000000000000');
                expect(userDetail.depositAmount).to.be.bignumber.equal('100000000000000000000');
                expect(userDetail.withdrawAmount).to.be.bignumber.equal('40000000000000000000');
                const totalWithdrawedAmount = await this.PreSale.totalWithdrawedAmount();
                expect(totalWithdrawedAmount).to.be.bignumber.equal('40000000000000000000');
            });
            it('claimTokens', async function () {
                await time.increase(new BN('604800000000'));
                let rewardAmount = await this.PreSale.unlockedToken(investor1);
                expect(rewardAmount).to.be.bignumber.equal('160000000000000000000');
                await this.PreSale.withdrawToken(new BN('160000000000000000000'), {from: investor1});
                const balance = await this.token.balanceOf(investor1);
                expect(balance).to.be.bignumber.equal('200000000000000000000');
                rewardAmount = await this.PreSale.unlockedToken(investor1);
                expect(rewardAmount).to.be.bignumber.equal('0');
                const userDetail = await this.PreSale.userDetail(investor1);
                expect(userDetail.totalRewardAmount).to.be.bignumber.equal('200000000000000000000');
                expect(userDetail.depositAmount).to.be.bignumber.equal('100000000000000000000');
                expect(userDetail.withdrawAmount).to.be.bignumber.equal('200000000000000000000');
                const totalWithdrawedAmount = await this.PreSale.totalWithdrawedAmount();
                expect(totalWithdrawedAmount).to.be.bignumber.equal('200000000000000000000');
            });
        });
    });
});
