const { expectRevert } = require("@openzeppelin/test-helpers");
const { assert } = require("chai");

const CrssToken = artifacts.require('CrssToken');

contract('CrssToken', ([alice, bob, carol, operator, owner]) => {
    beforeEach(async () => {
        this.crss = await CrssToken.new({ from: owner });
        this.burnAddress = '0x000000000000000000000000000000000000dEaD';
        this.zeroAddress = '0x0000000000000000000000000000000000000000';
    });

    it('only operator', async () => {
        assert.equal((await this.crss.owner()), owner);
        assert.equal((await this.crss.operator()), owner);

        await expectRevert(this.crss.updateTransferTaxRate(500, { from: operator }), 'operator: caller is not the operator');
        await expectRevert(this.crss.updateBurnRate(20, { from: operator }), 'operator: caller is not the operator');
        await expectRevert(this.crss.updateMaxTransferAmountRate(100, { from: operator }), 'operator: caller is not the operator');
        await expectRevert(this.crss.updateSwapAndLiquifyEnabled(true, { from: operator }), 'operator: caller is not the operator');
        await expectRevert(this.crss.setExcludedFromAntiWhale(operator, { from: operator }), 'operator: caller is not the operator');
        await expectRevert(this.crss.updateCrssSwapRouter(operator, { from: operator }), 'operator: caller is not the operator');
        await expectRevert(this.crss.updateMinAmountToLiquify(100, { from: operator }), 'operator: caller is not the operator');
        await expectRevert(this.crss.transferOperator(alice, { from: operator }), 'operator: caller is not the operator');
    });

    it('transfer operator', async () => {
        await expectRevert(this.crss.transferOperator(operator, { from: operator }), 'operator: caller is not the operator');
        await this.crss.transferOperator(operator, { from: owner });
        assert.equal((await this.crss.operator()), operator);

        await expectRevert(this.crss.transferOperator(this.zeroAddress, { from: operator }), 'CRSS::transferOperator: new operator is the zero address');
    });

    it('update transfer tax rate', async () => {
        await this.crss.transferOperator(operator, { from: owner });
        assert.equal((await this.crss.operator()), operator);

        assert.equal((await this.crss.transferTaxRate()).toString(), '500');
        assert.equal((await this.crss.burnRate()).toString(), '20');

        await this.crss.updateTransferTaxRate(0, { from: operator });
        assert.equal((await this.crss.transferTaxRate()).toString(), '0');
        await this.crss.updateTransferTaxRate(1000, { from: operator });
        assert.equal((await this.crss.transferTaxRate()).toString(), '1000');
        await expectRevert(this.crss.updateTransferTaxRate(1001, { from: operator }), 'CRSS::updateTransferTaxRate: Transfer tax rate must not exceed the maximum rate.');

        await this.crss.updateBurnRate(0, { from: operator });
        assert.equal((await this.crss.burnRate()).toString(), '0');
        await this.crss.updateBurnRate(100, { from: operator });
        assert.equal((await this.crss.burnRate()).toString(), '100');
        await expectRevert(this.crss.updateBurnRate(101, { from: operator }), 'CRSS::updateBurnRate: Burn rate must not exceed the maximum rate.');
    });

    it('transfer', async () => {
        await this.crss.transferOperator(operator, { from: owner });
        assert.equal((await this.crss.operator()), operator);

        await this.crss.mint(alice, 10000000, { from: owner }); // max transfer amount 25,000
        assert.equal((await this.crss.balanceOf(alice)).toString(), '10000000');
        assert.equal((await this.crss.balanceOf(this.burnAddress)).toString(), '0');
        assert.equal((await this.crss.balanceOf(this.crss.address)).toString(), '0');

        await this.crss.transfer(bob, 12345, { from: alice });
        assert.equal((await this.crss.balanceOf(alice)).toString(), '9987655');
        assert.equal((await this.crss.balanceOf(bob)).toString(), '11728');
        assert.equal((await this.crss.balanceOf(this.burnAddress)).toString(), '123');
        assert.equal((await this.crss.balanceOf(this.crss.address)).toString(), '494');

        await this.crss.approve(carol, 22345, { from: alice });
        await this.crss.transferFrom(alice, carol, 22345, { from: carol });
        assert.equal((await this.crss.balanceOf(alice)).toString(), '9965310');
        assert.equal((await this.crss.balanceOf(carol)).toString(), '21228');
        assert.equal((await this.crss.balanceOf(this.burnAddress)).toString(), '346');
        assert.equal((await this.crss.balanceOf(this.crss.address)).toString(), '1388');
    });

    it('transfer small amount', async () => {
        await this.crss.transferOperator(operator, { from: owner });
        assert.equal((await this.crss.operator()), operator);

        await this.crss.mint(alice, 10000000, { from: owner });
        assert.equal((await this.crss.balanceOf(alice)).toString(), '10000000');
        assert.equal((await this.crss.balanceOf(this.burnAddress)).toString(), '0');
        assert.equal((await this.crss.balanceOf(this.crss.address)).toString(), '0');

        await this.crss.transfer(bob, 19, { from: alice });
        assert.equal((await this.crss.balanceOf(alice)).toString(), '9999981');
        assert.equal((await this.crss.balanceOf(bob)).toString(), '19');
        assert.equal((await this.crss.balanceOf(this.burnAddress)).toString(), '0');
        assert.equal((await this.crss.balanceOf(this.crss.address)).toString(), '0');
    });

    it('transfer without transfer tax', async () => {
        await this.crss.transferOperator(operator, { from: owner });
        assert.equal((await this.crss.operator()), operator);

        assert.equal((await this.crss.transferTaxRate()).toString(), '500');
        assert.equal((await this.crss.burnRate()).toString(), '20');

        await this.crss.updateTransferTaxRate(0, { from: operator });
        assert.equal((await this.crss.transferTaxRate()).toString(), '0');

        await this.crss.mint(alice, 10000000, { from: owner });
        assert.equal((await this.crss.balanceOf(alice)).toString(), '10000000');
        assert.equal((await this.crss.balanceOf(this.burnAddress)).toString(), '0');
        assert.equal((await this.crss.balanceOf(this.crss.address)).toString(), '0');

        await this.crss.transfer(bob, 10000, { from: alice });
        assert.equal((await this.crss.balanceOf(alice)).toString(), '9990000');
        assert.equal((await this.crss.balanceOf(bob)).toString(), '10000');
        assert.equal((await this.crss.balanceOf(this.burnAddress)).toString(), '0');
        assert.equal((await this.crss.balanceOf(this.crss.address)).toString(), '0');
    });

    it('transfer without burn', async () => {
        await this.crss.transferOperator(operator, { from: owner });
        assert.equal((await this.crss.operator()), operator);

        assert.equal((await this.crss.transferTaxRate()).toString(), '500');
        assert.equal((await this.crss.burnRate()).toString(), '20');

        await this.crss.updateBurnRate(0, { from: operator });
        assert.equal((await this.crss.burnRate()).toString(), '0');

        await this.crss.mint(alice, 10000000, { from: owner });
        assert.equal((await this.crss.balanceOf(alice)).toString(), '10000000');
        assert.equal((await this.crss.balanceOf(this.burnAddress)).toString(), '0');
        assert.equal((await this.crss.balanceOf(this.crss.address)).toString(), '0');

        await this.crss.transfer(bob, 1234, { from: alice });
        assert.equal((await this.crss.balanceOf(alice)).toString(), '9998766');
        assert.equal((await this.crss.balanceOf(bob)).toString(), '1173');
        assert.equal((await this.crss.balanceOf(this.burnAddress)).toString(), '0');
        assert.equal((await this.crss.balanceOf(this.crss.address)).toString(), '61');
    });

    it('transfer all burn', async () => {
        await this.crss.transferOperator(operator, { from: owner });
        assert.equal((await this.crss.operator()), operator);

        assert.equal((await this.crss.transferTaxRate()).toString(), '500');
        assert.equal((await this.crss.burnRate()).toString(), '20');

        await this.crss.updateBurnRate(100, { from: operator });
        assert.equal((await this.crss.burnRate()).toString(), '100');

        await this.crss.mint(alice, 10000000, { from: owner });
        assert.equal((await this.crss.balanceOf(alice)).toString(), '10000000');
        assert.equal((await this.crss.balanceOf(this.burnAddress)).toString(), '0');
        assert.equal((await this.crss.balanceOf(this.crss.address)).toString(), '0');

        await this.crss.transfer(bob, 1234, { from: alice });
        assert.equal((await this.crss.balanceOf(alice)).toString(), '9998766');
        assert.equal((await this.crss.balanceOf(bob)).toString(), '1173');
        assert.equal((await this.crss.balanceOf(this.burnAddress)).toString(), '61');
        assert.equal((await this.crss.balanceOf(this.crss.address)).toString(), '0');
    });

    it('max transfer amount', async () => {
        assert.equal((await this.crss.maxTransferAmountRate()).toString(), '50');
        assert.equal((await this.crss.maxTransferAmount()).toString(), '0');

        await this.crss.mint(alice, 1000000, { from: owner });
        assert.equal((await this.crss.maxTransferAmount()).toString(), '5000');

        await this.crss.mint(alice, 1000, { from: owner });
        assert.equal((await this.crss.maxTransferAmount()).toString(), '5005');

        await this.crss.transferOperator(operator, { from: owner });
        assert.equal((await this.crss.operator()), operator);

        await this.crss.updateMaxTransferAmountRate(100, { from: operator }); // 1%
        assert.equal((await this.crss.maxTransferAmount()).toString(), '10010');
    });

    it('anti whale', async () => {
        await this.crss.transferOperator(operator, { from: owner });
        assert.equal((await this.crss.operator()), operator);

        assert.equal((await this.crss.isExcludedFromAntiWhale(operator)), false);
        await this.crss.setExcludedFromAntiWhale(operator, true, { from: operator });
        assert.equal((await this.crss.isExcludedFromAntiWhale(operator)), true);

        await this.crss.mint(alice, 10000, { from: owner });
        await this.crss.mint(bob, 10000, { from: owner });
        await this.crss.mint(carol, 10000, { from: owner });
        await this.crss.mint(operator, 10000, { from: owner });
        await this.crss.mint(owner, 10000, { from: owner });

        // total supply: 50,000, max transfer amount: 250
        assert.equal((await this.crss.maxTransferAmount()).toString(), '250');
        await expectRevert(this.crss.transfer(bob, 251, { from: alice }), 'CRSS::antiWhale: Transfer amount exceeds the maxTransferAmount');
        await this.crss.approve(carol, 251, { from: alice });
        await expectRevert(this.crss.transferFrom(alice, carol, 251, { from: carol }), 'CRSS::antiWhale: Transfer amount exceeds the maxTransferAmount');

        //
        await this.crss.transfer(bob, 250, { from: alice });
        await this.crss.transferFrom(alice, carol, 250, { from: carol });

        await this.crss.transfer(this.burnAddress, 251, { from: alice });
        await this.crss.transfer(operator, 251, { from: alice });
        await this.crss.transfer(owner, 251, { from: alice });
        await this.crss.transfer(this.crss.address, 251, { from: alice });

        await this.crss.transfer(alice, 251, { from: operator });
        await this.crss.transfer(alice, 251, { from: owner });
        await this.crss.transfer(owner, 251, { from: operator });
    });

    it('update SwapAndLiquifyEnabled', async () => {
        await expectRevert(this.crss.updateSwapAndLiquifyEnabled(true, { from: operator }), 'operator: caller is not the operator');
        assert.equal((await this.crss.swapAndLiquifyEnabled()), false);

        await this.crss.transferOperator(operator, { from: owner });
        assert.equal((await this.crss.operator()), operator);

        await this.crss.updateSwapAndLiquifyEnabled(true, { from: operator });
        assert.equal((await this.crss.swapAndLiquifyEnabled()), true);
    });

    it('update min amount to liquify', async () => {
        await expectRevert(this.crss.updateMinAmountToLiquify(100, { from: operator }), 'operator: caller is not the operator');
        assert.equal((await this.crss.minAmountToLiquify()).toString(), '500000000000000000000');

        await this.crss.transferOperator(operator, { from: owner });
        assert.equal((await this.crss.operator()), operator);

        await this.crss.updateMinAmountToLiquify(100, { from: operator });
        assert.equal((await this.crss.minAmountToLiquify()).toString(), '100');
    });
});
