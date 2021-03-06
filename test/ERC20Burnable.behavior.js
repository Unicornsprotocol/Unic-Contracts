const { BN, constants, expectEvent, expectRevert } = require('@openzeppelin/test-helpers');
const { ZERO_ADDRESS } = constants;

const { expect } = require('chai');

function shouldBehaveLikeERC20Burnable (errorPrefix, owner, initialBalance, [burner]) {
  describe('burn owner tokens', function () {
    describe('when the given amount is not greater than balance of the sender', function () {
      context('for a zero amount', function () {
        shouldBurn(new BN(0));
      });

      context('for a non-zero amount', function () {
        shouldBurn(new BN(100));
      });

      function shouldBurn (amount) {
        beforeEach(async function () {
          ({ logs: this.logs } = await this.token.burn(owner,amount, { from: owner }));
        });

        it('burns the requested amount', async function () {
          expect(await this.token.balanceOf(owner)).to.be.bignumber.equal(initialBalance.sub(amount));
        });

        it('emits a transfer event', async function () {
          expectEvent.inLogs(this.logs, 'Transfer', {
            from: owner,
            to: ZERO_ADDRESS,
            value: amount,
          });
        });
      }
    });

    describe('when the given amount is greater than the balance of the sender', function () {
      const amount = initialBalance.addn(1);

      it('reverts', async function () {
        await expectRevert(this.token.burn(owner, amount, { from: owner }),
          `${errorPrefix}: burn amount exceeds balance`,
        );
      });
    });
  });

  describe('burnFrom', function () {
    describe('on success', function () {
      context('for a zero amount', function () {
        shouldBurnFrom(new BN(0));
      });

      context('for a non-zero amount', function () {
        shouldBurnFrom(new BN(100));
      });

      function shouldBurnFrom (amount) {
        const originalAllowance = amount.muln(3);

        beforeEach(async function () {
          await this.token.transfer(burner,originalAllowance,{from: owner});
          await this.token.approve(owner, originalAllowance, { from: burner });
          const { logs } = await this.token.burn(burner, amount, { from: owner });
          this.logs = logs;
        });

        it('burns the requested amount', async function () {
          expect(await this.token.balanceOf(burner)).to.be.bignumber.equal(originalAllowance.sub(amount));
        });

        it('decrements allowance', async function () {
          expect(await this.token.allowance(burner, owner)).to.be.bignumber.equal(originalAllowance.sub(amount));
        });

        it('emits a transfer event', async function () {
          expectEvent.inLogs(this.logs, 'Transfer', {
            from: burner,
            to: ZERO_ADDRESS,
            value: amount,
          });
        });

        it('emits a approval event', async function () {
          expectEvent.inLogs(this.logs, 'Approval', {
            owner: burner,
            spender: owner,
            value: originalAllowance.sub(amount),
          });
        });
      }
    });

    describe('when the given amount is greater than the balance of the sender', function () {
      const amount = initialBalance.addn(1);

      it('reverts', async function () {
        await this.token.transfer(burner,initialBalance,{from: owner});
        await this.token.approve(owner, amount, { from: burner });
        await expectRevert(this.token.burn(burner, amount, { from: owner }),
          'Unicorns: burn amount exceeds balance',
        );
      });
    });

    describe('when the given amount is greater than the allowance', function () {
      const allowance = new BN(100);

      it('reverts', async function () {
        await this.token.transfer(burner,allowance.addn(1),{from: owner});
        await this.token.approve(owner, allowance, { from: burner });
        await expectRevert(this.token.burn(burner, allowance.addn(1), { from: owner }),
          'Unicorns: Check for approved token count failed',
        );
      });
    });
  });
}

module.exports = {
  shouldBehaveLikeERC20Burnable,
};
