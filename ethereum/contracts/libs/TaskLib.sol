// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

library TaskLib {
	enum Statuses { Created , Pending, Complete }

	struct Task {
		// @TODO include test for string length limitation
		address creator;
		string text; // the todo
		Statuses status; // status
		address delegate;
	}
}
