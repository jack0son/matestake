// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

library TaskLib {
	enum Statuses { Created , Pending, Complete }

	struct Task {
		address creator;
		string text; // the todo description
		Statuses status; // status
		address delegate;
	}
}
