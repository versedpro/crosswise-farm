const { expectRevert } = require('@openzeppelin/test-helpers');
const { assert } = require("chai");

const CrssReferral = artifacts.require('CrssReferral');

contract('CrssReferral', ([alice, bob, carol, referrer, operator, owner]) => {
    beforeEach(async () => {
        this.CrssReferral = await CrssReferral.new({ from: owner });
        this.zeroAddress = '0x0000000000000000000000000000000000000000';
    });

    it('should allow operator and only owner to update operator', async () => {
        assert.equal((await this.CrssReferral.operators(operator)).valueOf(), false);
        await expectRevert(this.CrssReferral.recordReferral(alice, referrer, { from: operator }), 'Operator: caller is not the operator');

        await expectRevert(this.CrssReferral.updateOperator(operator, true, { from: carol }), 'Ownable: caller is not the owner');
        await this.CrssReferral.updateOperator(operator, true, { from: owner });
        assert.equal((await this.CrssReferral.operators(operator)).valueOf(), true);

        await this.CrssReferral.updateOperator(operator, false, { from: owner });
        assert.equal((await this.CrssReferral.operators(operator)).valueOf(), false);
        await expectRevert(this.CrssReferral.recordReferral(alice, referrer, { from: operator }), 'Operator: caller is not the operator');
    });

    it('record referral', async () => {
        assert.equal((await this.CrssReferral.operators(operator)).valueOf(), false);
        await this.CrssReferral.updateOperator(operator, true, { from: owner });
        assert.equal((await this.CrssReferral.operators(operator)).valueOf(), true);

        await this.CrssReferral.recordReferral(this.zeroAddress, referrer, { from: operator });
        await this.CrssReferral.recordReferral(alice, this.zeroAddress, { from: operator });
        await this.CrssReferral.recordReferral(this.zeroAddress, this.zeroAddress, { from: operator });
        await this.CrssReferral.recordReferral(alice, alice, { from: operator });
        assert.equal((await this.CrssReferral.getReferrer(alice)).valueOf(), this.zeroAddress);
        assert.equal((await this.CrssReferral.referralsCount(referrer)).valueOf(), '0');

        await this.CrssReferral.recordReferral(alice, referrer, { from: operator });
        assert.equal((await this.CrssReferral.getReferrer(alice)).valueOf(), referrer);
        assert.equal((await this.CrssReferral.referralsCount(referrer)).valueOf(), '1');

        assert.equal((await this.CrssReferral.referralsCount(bob)).valueOf(), '0');
        await this.CrssReferral.recordReferral(alice, bob, { from: operator });
        assert.equal((await this.CrssReferral.referralsCount(bob)).valueOf(), '0');
        assert.equal((await this.CrssReferral.getReferrer(alice)).valueOf(), referrer);

        await this.CrssReferral.recordReferral(carol, referrer, { from: operator });
        assert.equal((await this.CrssReferral.getReferrer(carol)).valueOf(), referrer);
        assert.equal((await this.CrssReferral.referralsCount(referrer)).valueOf(), '2');
    });

    it('record referral commission', async () => {
        assert.equal((await this.CrssReferral.totalReferralCommissions(referrer)).valueOf(), '0');

        await expectRevert(this.CrssReferral.recordReferralCommission(referrer, 1, { from: operator }), 'Operator: caller is not the operator');
        await this.CrssReferral.updateOperator(operator, true, { from: owner });
        assert.equal((await this.CrssReferral.operators(operator)).valueOf(), true);

        await this.CrssReferral.recordReferralCommission(referrer, 1, { from: operator });
        assert.equal((await this.CrssReferral.totalReferralCommissions(referrer)).valueOf(), '1');

        await this.CrssReferral.recordReferralCommission(referrer, 0, { from: operator });
        assert.equal((await this.CrssReferral.totalReferralCommissions(referrer)).valueOf(), '1');

        await this.CrssReferral.recordReferralCommission(referrer, 111, { from: operator });
        assert.equal((await this.CrssReferral.totalReferralCommissions(referrer)).valueOf(), '112');

        await this.CrssReferral.recordReferralCommission(this.zeroAddress, 100, { from: operator });
        assert.equal((await this.CrssReferral.totalReferralCommissions(this.zeroAddress)).valueOf(), '0');
    });
});
