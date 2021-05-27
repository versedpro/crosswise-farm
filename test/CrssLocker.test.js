const { expectRevert } = require('@openzeppelin/test-helpers');
const { assert } = require("chai");
const CrssLocker = artifacts.require('CrssLocker');
const MockBEP20 = artifacts.require('libs/MockBEP20');


contract('CrssLocker', ([alice, bob, carol, owner]) => {
    beforeEach(async () => {
        this.lp1 = await MockBEP20.new('LPToken', 'LP1', '1000000', { from: owner });
        this.CrssLocker = await CrssLocker.new({ from: owner });
    });

    it('only owner', async () => {
        assert.equal((await this.CrssLocker.owner()), owner);

        // lock
        await this.lp1.transfer(this.CrssLocker.address, '2000', { from: owner });
        assert.equal((await this.lp1.balanceOf(this.CrssLocker.address)).toString(), '2000');

        await expectRevert(this.CrssLocker.unlock(this.lp1.address, bob, { from: bob }), 'Ownable: caller is not the owner');
        await this.CrssLocker.unlock(this.lp1.address, carol, { from: owner });
        assert.equal((await this.lp1.balanceOf(carol)).toString(), '2000');
        assert.equal((await this.lp1.balanceOf(this.CrssLocker.address)).toString(), '0');
    });
})
