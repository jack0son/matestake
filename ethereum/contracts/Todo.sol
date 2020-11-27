// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "./libs/TaskLib.sol";
import "./libs/Helpers.sol";

/*
 * @notice Append only todo list contract
 * @dev Adding ability to stake ETH on a task
 */
contract Todo {
	uint16 constant TASK_TEXT_LENGTH = 256; // bytes

	mapping(uint256 => address) private creatorsByTaskId; // O(1) authorization checks
	mapping(uint256 => TaskLib.Task) private tasksById;

	uint256 taskCounter = 0; // tasks are append only
	uint256 discountPerBlock; // portion of stake to slash per block overdue
	uint burned; // slashed stakes are burned, harsh

	/*
	 * @param _discountPerBlock Fraction of stake to slash per block past deadline
	 */
	constructor(uint256 _discountPerBlock) {
		discountPerBlock = _discountPerBlock;
	}

	/*
	 * @notice Create a new task which must be completed with a certain number of blocks
	 * @dev Task that will tigger a slashing event after the deadline passes - Eth alarm clock would be better here
	 * @param _text Text description of the task
	 * @param _blocksToComplete Number of blocks until creator gets slashed
	 * @returns task's allocated ID
	 */
	function createTask(string calldata _text, address _mate, uint256 _blocksToComplete) external payable
	returns (uint256 taskId) {
		require(_mate != address(0), 'Mate address cannot be empty');
		require(_blocksToComplete > 0, 'Time limit in blocks must be positive');

		bytes memory text = bytes(_text);
		require(bytes(text).length <= TASK_TEXT_LENGTH, 'Text length exceeds maxium');
		require(bytes(text).length > 0, 'Text cannot be empty');

		// Create the task entry
		taskId = taskCounter++;
		address payable creator = msg.sender;
		tasksById[taskId] = TaskLib.Task({
			creator: creator,
			stake: msg.value,
			text: _text,
			status: TaskLib.Statuses.Created,
			delegate: address(0),
			blockStarted: 0,
			blocksToComplete: _blocksToComplete
		});

		creatorsByTaskId[taskId] = creator;

		emit Created(creator, taskId, creator, taskId);
		return taskId;
	}

	/*
	 * @notice Delegate a task to another address
	 * @dev Delegate address may progress the task, but not assign other delegates
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
		TaskLib.Task storage task = tasksById[_taskId];
		task.status = TaskLib.Statuses(uint8(task.status) + 1);

		if(task.status == TaskLib.Statuses.Pending) {
			task.blockStarted = block.number;
		} else if(task.status == TaskLib.Statuses.Complete) {
			uint refund = _calculateRefund(task.stake, task.blockStarted, task.blocksToComplete);
			if(refund > 0) {
				task.creator.transfer(refund);
			}

			emit Complete(_taskId, _taskId, refund);
		}

		emit Status(_taskId, uint8(tasksById[_taskId].status), _taskId, uint8(tasksById[_taskId].status));
	}

	/*
	 * @notice Caclulate how much of the stake to return to the task creator
	 * @dev Params as in Helpers._calculateRefund
	 */
	function _calculateRefund(uint stake, uint started, uint blocksToComplete) internal view returns (uint256) {
		// @fix sacrificing gas (with additional callstack depth) in favour of clarity / testability
		return Helpers._caculateRefund(stake, started, blocksToComplete, block.number, discountPerBlock);
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
	event Complete(uint256 indexed idx_taskId, uint256 taskId, uint256 refund);
}
