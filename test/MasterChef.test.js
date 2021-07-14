const { expectRevert, time } = require('@openzeppelin/test-helpers');
const { assert } = require("chai");
const CrssToken = artifacts.require('CrssToken');
const xCrssToken = artifacts.require('xCrssToken');
const MasterChef = artifacts.require('MasterChef');
const MockBEP20 = artifacts.require('MockBEP20');
const CrssReferral = artifacts.require('CrssReferral');

contract('MasterChef', ([alice, bob, carol, referrer, treasury, dev, buyback, fee, owner]) => {
    beforeEach(async () => {
        this.zeroAddress = '0x0000000000000000000000000000000000000000';
        this.crss = await CrssToken.new(dev, buyback, { from: owner });
        this.xcrss = await xCrssToken.new({ from: owner });
        // this.crss = await CrssToken.new({ from: owner });
        this.referral = await CrssReferral.new({ from: owner });
        const startBlock = (await time.latestBlock()).toString();
        this.chef = await MasterChef.new(this.crss.address, this.xcrss.address, owner, owner, startBlock, { from: owner });

        await this.crss.transferOwnership(this.chef.address, { from: owner });
        await this.referral.updateOperator(this.chef.address, true, { from: owner });
        // await this.chef.setCrssReferral(this.referral.address, { from: owner });

        this.lp1 = await MockBEP20.new('LPToken', 'LP1', { from: owner });
        this.lp2 = await MockBEP20.new('LPToken', 'LP2', { from: owner });
        this.lp3 = await MockBEP20.new('LPToken', 'LP3', { from: owner });
        this.lp4 = await MockBEP20.new('LPToken', 'LP4', { from: owner });

        await this.lp1.mint(owner, 1000000, { from: owner });
        await this.lp2.mint(owner, 1000000, { from: owner });
        await this.lp3.mint(owner, 1000000, { from: owner });
        await this.lp4.mint(owner, 1000000, { from: owner });

        await this.lp1.transfer(alice, '2000', { from: owner });
        await this.lp2.transfer(alice, '2000', { from: owner });
        await this.lp3.transfer(alice, '2000', { from: owner });
        await this.lp4.transfer(alice, '2000', { from: owner });

        await this.lp1.transfer(bob, '2000', { from: owner });
        await this.lp2.transfer(bob, '2000', { from: owner });
        await this.lp3.transfer(bob, '2000', { from: owner });
        await this.lp4.transfer(bob, '2000', { from: owner });

        await this.lp1.transfer(carol, '2000', { from: owner });
        await this.lp2.transfer(carol, '2000', { from: owner });
        await this.lp3.transfer(carol, '2000', { from: owner });
        await this.lp4.transfer(carol, '2000', { from: owner });
    });

    it('deposit fee', async () => {
        assert.equal((await this.chef.owner()), owner);
        assert.equal((await this.chef.devAddress()), owner);
        assert.equal((await this.chef.treasuryAddress()), owner);

        await this.chef.setDevAddress(dev, { from: owner });
        assert.equal((await this.chef.devAddress()), dev);

        await this.chef.setTreasuryAddress(treasury, { from: owner });
        assert.equal((await this.chef.treasuryAddress()), treasury);

        await this.chef.add('1000', this.lp1.address, '400', true, { from: owner });
        await this.chef.add('2000', this.lp2.address, '0', true, { from: owner });

        await this.lp1.approve(this.chef.address, '1000', { from: alice });
        await this.lp2.approve(this.chef.address, '1000', { from: alice });

        assert.equal((await this.lp1.balanceOf(dev)).toString(), '0');
        await this.chef.deposit(0, '100', referrer, { from: alice });
        assert.equal((await this.lp1.balanceOf(dev)).toString(), '2');
        assert.equal((await this.lp1.balanceOf(treasury)).toString(), '2');

        assert.equal((await this.lp2.balanceOf(dev)).toString(), '0');
        await this.chef.deposit(1, '100', referrer, { from: alice });
        assert.equal((await this.lp2.balanceOf(dev)).toString(), '0');
        assert.equal((await this.lp2.balanceOf(treasury)).toString(), '0');
    });

    it('only dev', async () => {
        assert.equal((await this.chef.owner()), owner);
        assert.equal((await this.chef.devAddress()), owner);

        await expectRevert(this.chef.setDevAddress(dev, { from: dev }), 'setDevAddress: FORBIDDEN');
        await this.chef.setDevAddress(dev, { from: owner });
        assert.equal((await this.chef.devAddress()), dev);

        await expectRevert(this.chef.setDevAddress(this.zeroAddress, { from: dev }), 'setDevAddress: ZERO');
    });

    it('only treasury', async () => {
        assert.equal((await this.chef.owner()), owner);
        assert.equal((await this.chef.treasuryAddress()), owner);

        await expectRevert(this.chef.setTreasuryAddress(treasury, { from: treasury }), 'setTreasuryAddress: FORBIDDEN');
        await this.chef.setTreasuryAddress(treasury, { from: owner });
        assert.equal((await this.chef.treasuryAddress()), treasury);

        await expectRevert(this.chef.setTreasuryAddress(this.zeroAddress, { from: treasury }), 'setTreasuryAddress: ZERO');
    });
});
