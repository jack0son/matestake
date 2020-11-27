const { accounts, contract, web3 } = require('@openzeppelin/test-environment');
const chai = require('chai');
chai.should();
const { expect } = chai;
const chaiAsPromised = require('chai-as-promised');
const assert = require('assert');

const { Status, Statuses, isStatus } = require('../lib/todo.js');

const {
	BN, // Big Number support
	constants, // Common constants, like the zero address and largest integers
	expectEvent, // Assertions for emitted events
	expectRevert, // Assertions for transactions that should fail
} = require('@openzeppelin/test-helpers');

const Todo = contract.fromArtifact('Todo');
const [a_creator, a_delegate, a_mate, a_stranger, a_a, a_b, a_c, a_d, ...other_accounts] = accounts;

const taskText = 'build stakeamate app';

describe('todo Contract', function() {
	let todo;

	const expectTaskStatus = async (taskId, status) => {
		if (taskId === undefined || taskId === null) throw new Error(`Invalid task ID: ${taskId}`);
		if (!isStatus(status)) throw new Error(`Invalid status: ${status}`);
		return expect(Status(await todo.getTaskStatus(taskId, { from: a_creator }))).to.equal(status);
	};

	beforeEach('Deploy WokeToken', async function() {
		todo = await Todo.new({ from: a_creator });
	});

	describe('tasks', function() {
		it('can be created', async function() {
			let rx = await todo.createTask(taskText, { from: a_creator });

			const firstTaskId = new BN(0);

			// Check event was emitted
			expectEvent(rx, 'Created', {
				taskId: firstTaskId,
				creator: a_creator,
			});

			let taskId = rx.logs[0].args.taskId;
			assert(taskId.eq(firstTaskId));

			// Check task exists
			expect(await todo.taskText(taskId, { from: a_creator })).to.equal(taskText);
			expect(Status(await todo.getTaskStatus(taskId, { from: a_creator }))).to.equal(Statuses.Created);
		});

		it('update from Created to Pending to Completed', async function() {
			let taskId = (await todo.createTask(taskText, { from: a_creator })).logs[0].args.taskId;

			await expectTaskStatus(taskId, Statuses.Created);

			await todo.progressTask(taskId, { from: a_creator });
			await expectTaskStatus(taskId, Statuses.Pending);

			await todo.progressTask(taskId, { from: a_creator });
			await expectTaskStatus(taskId, Statuses.Complete);
		});

		it('revert when task does not exists', async function() {
			await expectRevert(todo.progressTask(0, { from: a_creator }), 'Task does not exist');
			await todo.createTask(taskText, { from: a_creator });

			// Check for modifier precedence (should not check authorization if task
			// does not exist).
			await expectRevert(todo.progressTask(1, { from: a_creator }), 'Task does not exist');
			await expectRevert(todo.delegateTask(1, a_delegate, { from: a_creator }), 'Task does not exist');
		});

		it('revert when sender is not authorized', async function() {
			await todo.createTask(taskText, { from: a_creator });
			await expectTaskStatus(0, Statuses.Created);
			await expectRevert(todo.progressTask(0, { from: a_stranger }), 'Sender is not creator or delegate');
		});

		it('should not allow updates to a completed task', async function() {
			let taskId = (await todo.createTask(taskText, { from: a_creator })).logs[0].args.taskId;
			await todo.progressTask(taskId, { from: a_creator });
			await todo.progressTask(taskId, { from: a_creator });

			await expectRevert(todo.progressTask(taskId, { from: a_creator }), 'Task already complete');
			await expectRevert(todo.delegateTask(taskId, a_delegate, { from: a_creator }), 'Task is not in correct state');
		});
	});

	describe('staked tasks', function() {});

	describe('timed tasks', function() {
		it('should return the stake', async function() {
			this.skip();
		});
	});

	describe('load', function() {
		let stressLoad = 10;

		it(`should handle ${stressLoad} tasks`, async function() {
			this.timeout(10000);
			for (let i = 0; i < stressLoad; i++) {
				await todo.createTask(`task_${i.toString().padStart(3)}`, { from: other_accounts[i] });
			}

			const completeAllTasks = [];

			// Move all the tasts through each state
			for (let i = 0; i < stressLoad; i++) {
				completeAllTasks.push(
					todo
						.progressTask(i, { from: other_accounts[i] })
						.then(() => todo.progressTask(i, { from: other_accounts[i] }))
						.then(() => expectTaskStatus(i, Statuses.Complete))
				);
			}

			await Promise.all(completeAllTasks);
		});
	});

	// @TODO group tests by feature not good path vs corner cases
	describe('delegated tasks', function() {
		it('should allow a task to be delegated', async function() {
			this.skip();
		});

		it('should not be able to delegate', async function() {
			this.skip();
		});

		it('should not be able to delegate if pending or completed', async function() {
			this.skip();
		});
	});

	describe('corner cases', function() {
		it('Check for overflow on taskId', async function() {
			// How does web3 interpret bigger than 256 bit number?
			this.skip();
		});

		it('', async function() {
			this.skip();
		});
	});
});
