// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

library TaskLib {
	enum Statuses { Created , Pending, Complete }

	struct Task {
		// @TODO include test for string length limitation
		address payable creator;
		address mate; // verifies that task is complete
		uint stake; // staked wei
		string text; // the todo
		Statuses status; // status
		address delegate;
		uint blockStarted; // block number the task was created
		uint blocksToComplete; // number of blocks until stake is slashed
	}
}
