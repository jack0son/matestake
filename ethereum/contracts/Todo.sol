// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "./libs/TaskLib.sol";

/*
 * @notice Append only todo list contaract
 * @dev Modifiers are used to improve upgradablity / extendability
 * @dev Adding ability to stake ETH on a task
 */
contract Todo {
	uint16 constant TASK_TEXT_LENGTH = 256; // byes

	mapping(uint256 => address) private creatorsByTaskId; // O(1) authorization checks
	mapping(uint256 => TaskLib.Task) private tasksById;

	uint256 taskCounter = 0; // tasks are append only

	constructor() {
	}

	/*
	 * @notice Create a new task with a text description
	 * @param _text Text description of the task
	 * @returns task's allocated ID
	 */
	function createTask(string calldata _text) external returns (uint256 taskId) {

		// Validate task
		bytes memory text = bytes(_text);
		require(bytes(text).length <= TASK_TEXT_LENGTH, 'Text length exceeds maxium');
		require(bytes(text).length > 0, 'Text cannot be empty');

		// Create task
		address creator = msg.sender;
		taskId = taskCounter++;
		tasksById[taskId] = TaskLib.Task({ creator: creator, text: _text, status: TaskLib.Statuses.Created, delegate: address(0)});
		creatorsByTaskId[taskId] = creator;

		emit Created(creator, taskId, creator, taskId);

		return taskId;
	}

	/*
	 * @notice Delegate a task to another address
	 * @dev Delegate address may progress the task, but not assign new delegates
	 * @param _taskId Task's ID
	 * @param _delegate Delegate's address
	 */
	function delegateTask(uint256 _taskId, address _delegate) external
	taskExists(_taskId)
	onlyCreator(_taskId)
	{
		require(tasksById[_taskId].status == TaskLib.Statuses.Created, 'Cannot delegate once started');
		// Nonsensical paths should be asserted
		require(_delegate != msg.sender, 'Creator cannot be delegate');
		tasksById[_taskId].delegate = _delegate;
	}

	/*
	 * @notice Progress the task to it's next status
	 * @dev Tasks can only progress in single increments through the statuses
	 * @param _taskId Task's ID
	 */
	function progressTask(uint256 _taskId) external
	taskExists(_taskId)
	onlyAuthorized(_taskId)
	taskNotComplete(_taskId)
	{
		tasksById[_taskId].status = TaskLib.Statuses(uint8(tasksById[_taskId].status) + 1);

		emit Status(_taskId, uint8(tasksById[_taskId].status), _taskId, uint8(tasksById[_taskId].status));
	}


	// Internal functions
	function _isTaskCreator(uint256 _taskId) internal view returns (bool) {
		return msg.sender == creatorsByTaskId[_taskId];
	}

	function _isTaskDelegate(uint256 _taskId) internal view returns (bool) {
		return msg.sender == tasksById[_taskId].delegate;
	}

	function _isAuthorized(uint256 _taskId) internal view returns (bool) {
		return _isTaskCreator(_taskId) || _isTaskDelegate(_taskId);
	}

	function _taskExists(uint256 _taskId) internal view returns (bool) {
		// Works because there is no task deletion
		return _taskId < taskCounter;
	}

	modifier taskExists(uint256 _taskId) {
		require(_taskExists(_taskId), 'Task does not exist');
		_;
	}

	// Modifiers
	// @dev Using internal functions for modifiers saves substantial gas
	modifier onlyCreator(uint256 _taskId) {
		require(_isTaskCreator(_taskId), 'Sender is not creator');
		_;
	}

	modifier onlyAuthorized(uint256 _taskId) {
		require(_isAuthorized(_taskId), 'Sender is not creator or delegate');
		_;
	}

	modifier taskNotComplete(uint256 _taskId) {
		require(tasksById[_taskId].status != TaskLib.Statuses.Complete, 'Task already complete');
		_;
	}

	modifier onlyTaskCreator(uint256 _taskId) {
		require(_isTaskCreator(_taskId), 'sender not task creator');
		_;
	}

	// View API
	function taskText(uint256 _taskId) external view
	taskExists(_taskId)
	returns (string memory text)
	{
		return tasksById[_taskId].text;
	}

	function getTaskStatus(uint256 _taskId) external view
	taskExists(_taskId)
	returns (TaskLib.Statuses)
	{
		return tasksById[_taskId].status;
	}

	function isTaskDelegate(uint256 _taskId) external view returns (bool) {
		return msg.sender == tasksById[_taskId].delegate;
	}

	event Created(address indexed idx_creator, uint256 indexed idx_taskId, address creator, uint256 taskId);
	event Status(uint256 indexed idx_taskId, uint8 indexed idx_status, uint256 taskId, uint8 status);
}
