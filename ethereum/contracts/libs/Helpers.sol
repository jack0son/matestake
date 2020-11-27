// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

library Helpers {
	/*
	 * @notice Public access to _caculateRefund()
	 * @dev Makes testing easier - Could inherit from a mock contract instead
	 * @returns task's allocated ID
	 */
	function calculateRefund(uint stake, uint created, uint blocksToComplete, uint currentBlock, uint discountPerBlock)
		public pure
		returns (uint refund)
	{
		return _caculateRefund(stake, created, blocksToComplete, currentBlock, discountPerBlock);
	}

	/*
	 * @notice Calculate how much of a task's stake to return
	 * @returns task's allocated ID
	 */
	function _caculateRefund(uint stake, uint created, uint blocksToComplete, uint currentBlock, uint discountPerBlock)
		internal pure
		returns (uint refund)
	{
		if(stake == 0) {
			return 0;
		}

		// Caculate deadline then compare to avoid signed math complications
		uint deadlineBlock = created + blocksToComplete;
		if(deadlineBlock > currentBlock) {
			// Full stake refuned
			return stake;
		} else {
			uint overdue = (currentBlock - deadlineBlock);
			if(overdue > discountPerBlock) {
				return 0; // too far over the deadline
			}

			uint slashProportion = discountPerBlock - overdue;
			return stake * slashProportion / discountPerBlock;
		}

	}

	event Trace(uint block);
}
