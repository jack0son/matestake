// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

library Helpers {
	/*
	 * @notice Public access to _caculateRefund()
	 * @dev Makes testing easier - Could inherit from a mock contract instead
	 * @returns task's allocated ID
	 */
	function calculateRefund(uint stake, uint created, uint blocksToComplete, uint discountPerBlock, uint currentBlock)
		public pure
		returns (uint refund) 
	{
		return _caculateRefund(stake, created, blocksToComplete, discountPerBlock, currentBlock);
	}

	/*
	 * @notice Calculate how much of a task's stake to return
	 * @returns task's allocated ID
	 */
	function _caculateRefund(uint stake, uint created, uint blocksToComplete, uint discountPerBlock, uint currentBlock)
		internal pure
		returns (uint refund)
	{
		// Caculate deadline then compare to avoid signed math complications
		uint deadlineBlock = created + blocksToComplete;
		if(deadlineBlock > currentBlock) {
			// Full stake refuned
			refund = stake;
			return refund;
		} else {
			uint discount = currentBlock - deadlineBlock * stake;
			discount = discount / discountPerBlock;

			if(discount > stake) {
				return stake;
			}

			refund = stake - discount;
		}

		return refund;
	}
}
