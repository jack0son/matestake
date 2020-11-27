// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "./libs/TaskLib.sol";


// Start building a solidity checklist...
// @TODO check all state vars have correct visibility 
// @TODO check function singature style used by NuCypher
// @TODO Check doc format from solidity docs)
// @TODO Check whether return types should be memory or calldata

// contract Todo is Ownable {
contract Todo {
	uint16 constant TASK_TEXT_LENGTH = 256; // byes

	mapping(uint256 => address) private creatorsByTaskId; // O(1) authorization checks
	mapping(uint256 => TaskLib.Task) private tasksById;

	uint256 taskCounter = 0; // tasks are append only

	constructor() {
	}

	function createTask(string calldata _text) external returns (uint256 taskId) {
		// validate task
		address creator = msg.sender;
		// address delegate = _delegate != address(0) ;

		bytes memory text = bytes(_text);
		require(bytes(text).length <= TASK_TEXT_LENGTH, 'text length exceeds maxium');

		taskId = taskCounter++;
		tasksById[taskId] = TaskLib.Task({ creator: creator, text: _text, status: TaskLib.Statuses.Created, delegate: address(0)});
		creatorsByTaskId[taskId] = creator;

		emit Created(creator, taskId, creator, taskId);

		return taskId;
	}

	// Task that will tigger a slashing event after the deadline passes
	// function createStakedTask(string _text, address mate) payable {
	// uint256 stake = msg.value;
	// }

	function delegateTask(uint256 _taskId, address _delegate) external
	taskExists(_taskId)
	onlyCreator(_taskId)
	taskStatusIs(_taskId, TaskLib.Statuses.Created)
	{
		tasksById[_taskId].delegate = _delegate;
	}

	function progressTask(uint256 _taskId) external
	taskExists(_taskId)
	onlyAuthorized(_taskId)
	taskNotComplete(_taskId)
	{
		tasksById[_taskId].status = TaskLib.Statuses(uint8(tasksById[_taskId].status) + 1);

		emit Status(_taskId, uint8(tasksById[_taskId].status), _taskId, uint8(tasksById[_taskId].status));

		// @TODO return stake
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
		return _taskId < taskCounter;
	}

	// Works because there is no task deletion
	modifier taskExists(uint256 _taskId) {
		require(_taskExists(_taskId), 'Task does not exist');
		_;
	}

	// Modifiers
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

	modifier taskStatusIs(uint256 _taskId, TaskLib.Statuses _status) {
		require(tasksById[_taskId].status == _status, 'Task is not in correct state');
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
