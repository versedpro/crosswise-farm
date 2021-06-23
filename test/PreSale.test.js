const { BN, constants, expectEvent, time, expectRevert, ether, balance } = require('@openzeppelin/test-helpers');
const { ZERO_ADDRESS } = constants;

const { expect } = require('chai');

const CrssToken = artifacts.require('MockBEP20');
const PreSale = artifacts.require('PreSale');


function seconds_since_epoch(){ 
    var d = new Date();
    return Math.floor( d.getTime() / 1000 ); 
}
  

contract('CrssToken Test', function ([owner, masterWallet, investor1, investor2]) {

    const name = 'Cross Token';
    const symbol = 'Crss';
    const decimal = new BN('18');


    const tokenSupply = new BN('100000000000000000000000000');
    const hardCap = new BN('200000000000000000000000');
    const softCap = new BN('50000000000000000000000');
    const ONE_TOKEN = new BN('1000000000000000000');
    const TEN_TOKEN = new BN('10000000000000000000');
    const hardCapOverflow = new BN('2000000000000000000000000');
    const maxBusdPerWallet = new BN('1000000000000000000000');
    const maxBusdPerWalletOverflow = new BN('2000000000000000000000');

    before(async function () {
        this.token = await CrssToken.new(name, symbol, {from: owner});
        this.busd = await CrssToken.new("busd", "busd", {from: owner});
        const startTime = new BN(seconds_since_epoch().toString());
        this.PreSale = await PreSale.new(this.token.address, this.busd.address, masterWallet, startTime);
        this.token.mint(masterWallet, tokenSupply, {from: owner});
        this.busd.mint(investor1, tokenSupply, {from: owner});
    });


    describe('deposit', function () {
        context('validate', function() {
            it('revert because presale is not active', async function () {
                const startTime = new BN(seconds_since_epoch().toString()).add(new BN('10'));
                this.PreSaleNotActive = await PreSale.new(this.token.address, this.busd.address, masterWallet, startTime);
                await expectRevert(this.PreSaleNotActive.deposit(hardCapOverflow, {from:investor1}), "Presale.deposit: Presale is not active");
            })
            it('revert because hardcap limit', async function () {
                await expectRevert(this.PreSale.deposit(hardCapOverflow, {from:investor1}), "deposit is above hardcap limit");
            });

            it('revert because deposit before start time.', async function () {
                await expectRevert(this.PreSale.deposit(maxBusdPerWalletOverflow, {from:investor1}), "Presale.deposit: deposit amount is bigger than max deposit amount");
            });

            it('revert because not approved.', async function () {
                await expectRevert(this.PreSale.deposit(ONE_TOKEN, {from:investor1}), "BEP20: transfer amount exceeds allowance.");
            });

            it('revert because crss not approved.', async function () {
                await this.busd.approve(this.PreSale.address, ONE_TOKEN, {from: investor1});
                await expectRevert(this.PreSale.deposit(ONE_TOKEN, {from:investor1}), "BEP20: transfer amount exceeds allowance.");
            });
        });
        

        context('deposit success', async function () {
            before(async function () {
                await this.token.approve(this.PreSale.address, tokenSupply, {from: masterWallet});
            })
            it('deposit', async function () {
                await this.busd.approve(this.PreSale.address, ONE_TOKEN, {from: investor1});
                await this.PreSale.deposit(ONE_TOKEN, {from: investor1});
                expect(await this.token.balanceOf(investor1)).to.be.bignumber.equal(ether('2'));
            });
        });

    });
});
