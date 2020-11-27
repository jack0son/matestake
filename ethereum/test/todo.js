const chai = require('chai');
chai.use(require('chai-as-promised'));
chai.should();
const { expect, assert } = chai;
const { accounts, contract, web3 } = require('@openzeppelin/test-environment');
const { BN, constants, expectEvent, expectRevert } = require('@openzeppelin/test-helpers');

const { Status, Statuses, statusList, isStatus } = require('../lib/todo.js');
const statusToBN = (status) => new BN(statusList.indexOf(status));

const Todo = contract.fromArtifact('Todo');
const Helpers = contract.fromArtifact('Helpers');
const [a_owner, a_creator, a_delegate, a_mate, a_stranger, ...other_accounts] = accounts;

const taskText = 'build stakeamate app';
const discountPerBlock = new BN(1000);
const zero = new BN(0);
const one = new BN(1);
const two = new BN(2);

function calculateRefund(stake, createdBlock, numBlocks, currentBlock, discountPerBlock) {
	const overdue = currentBlock - (createdBlock + numBlocks);
	return ((discountPerBlock - overdue) * stake) / discountPerBlock;
}

describe('Todo Contract', function() {
	let todo, helpers;

	const expectTaskStatus = async (taskId, status) => {
		if (taskId === undefined || taskId === null) throw new Error(`Invalid task ID: ${taskId}`);
		if (!isStatus(status)) throw new Error(`Invalid status: ${status}`);
		return expect(Status(await todo.getTaskStatus.call(taskId, { from: a_creator }))).to.equal(status);
	};

	before(async function() {
		helpers = await Helpers.new({ from: a_owner });
	});

	beforeEach(async function() {
		todo = await Todo.new(discountPerBlock, { from: a_owner });
	});

	describe('Refunds', function() {
		const someWei = new BN(10000);

		it('no refund if no ETH is staked', async function() {
			return expect(helpers.calculateRefund.call(0, 0, 0, 0, discountPerBlock)).to.eventually.deep.equal(zero);
		});

		it('full refund if before deadline', async function() {
			const created = 1;
			const numBlocks = 2;
			const currentBlock = 2;

			assert(currentBlock < created + numBlocks);

			return expect(
				helpers.calculateRefund.call(someWei, created, numBlocks, currentBlock, discountPerBlock)
			).to.eventually.deep.equal(zero);
		});

		it('should not be slashed on the deadline', async function() {
			const created = 1;
			const numBlocks = 2;
			const currentBlock = 3;

			assert(currentBlock == created + numBlocks);

			return expect(
				helpers.calculateRefund.call(someWei, created, numBlocks, currentBlock, discountPerBlock)
			).to.eventually.deep.equal(someWei);
		});

		// @TODO confirm math in python for decimal cases
		it('should be discounted at discount proportion per block', async function() {
			const stake = 1000;
			const discount = 10;
			const created = 0;
			const numBlocks = 100;
			const currentBlock = 108;

			const expectedRefund = calculateRefund(stake, created, numBlocks, currentBlock, discount);
			assert(expectedRefund > 0);

			await expect(
				helpers.calculateRefund.call(stake, created, numBlocks, currentBlock, discountPerBlock)
			).to.eventually.deep.equal(new BN(expectedRefund + 1));

			await expect(helpers.calculateRefund.call(1000, 0, 10, 109, 100)).to.eventually.deep.equal(new BN(10));
			await expect(helpers.calculateRefund.call(1000, 0, 10, 109, 100)).to.eventually.deep.equal(new BN(0));
		});

		it('should be zero if number of blocks equal to discount have passed', async function() {
			const stake = 1000;
			const discount = 10;
			const created = 0;
			const numBlocks = 100;
			const currentBlock = 110;

			const expectedRefund = calculateRefund(stake, created, numBlocks, currentBlock, discount);
			assert(expectedRefund == 0);

			return expect(
				helpers.calculateRefund.call(stake, created, numBlocks, currentBlock, discountPerBlock)
			).to.eventually.deep.equal(new BN(expectedRefund));
		});

		it('should be zero if overdue', async function() {
			const stake = 1000;
			const discount = 10;
			const created = 0;
			const numBlocks = 100;
			const currentBlock = 111;

			const expectedRefund = calculateRefund(stake, created, numBlocks, currentBlock, discount);
			assert(expectedRefund < 0);

			return expect(
				helpers.calculateRefund.call(stake, created, numBlocks, currentBlock, discountPerBlock)
			).to.eventually.deep.equal(new BN(expectedRefund));
		});
	});

	describe('Tasks', function() {
		it('can be created', async function() {
			let rx = await todo.createTask(taskText, a_mate, one, { from: a_creator });

			const firstTaskId = new BN(0);

			// Check event was emitted
			expectEvent(rx, 'Created', { taskId: firstTaskId, creator: a_creator });

			let taskId = rx.logs[0].args.taskId;
			expect(taskId.eq(firstTaskId)).to.be.true;

			// Check task exists
			expect(await todo.taskText(taskId, { from: a_creator })).to.equal(taskText);
			await expectTaskStatus(taskId, Statuses.Created);
		});

		it('status should progress from Created to Pending to Completed', async function() {
			let taskId = (await todo.createTask(taskText, a_mate, one, { from: a_creator })).logs[0].args.taskId;

			await expectTaskStatus(taskId, Statuses.Created);

			let rx = await todo.progressTask(taskId, { from: a_creator });
			expectEvent(rx, 'Status', { taskId: taskId, status: statusToBN(Statuses.Pending) });
			await expectTaskStatus(taskId, Statuses.Pending);

			rx = await todo.progressTask(taskId, { from: a_creator });
			expectEvent(rx, 'Status', { taskId: taskId, status: statusToBN(Statuses.Complete) });
			await expectTaskStatus(taskId, Statuses.Complete);
		});

		it('revert if task text has invalid length', async function() {
			const validText = Array(257).join('!');
			assert(validText.length, 256);
			await todo.createTask(validText, a_mate, one, { from: a_creator });

			const edge = Array(258).join('!');
			assert(edge.length, 257);
			await expectRevert(todo.createTask(edge, a_mate, one, { from: a_creator }), 'Text length exceeds maxium');

			const rightOut = Array(300).join('!');
			await expectRevert(todo.createTask(rightOut, a_mate, one, { from: a_creator }), 'Text length exceeds maxium');

			await expectRevert(todo.createTask('', a_mate, one, { from: a_creator }), 'Text cannot be empty');
		});

		it('revert when task does not exists', async function() {
			await expectRevert(todo.progressTask(0, { from: a_creator }), 'Task does not exist');
			await todo.createTask(taskText, a_mate, one, { from: a_creator });

			// Check for modifier precedence (should not check authorization if task
			// does not exist).
			await expectRevert(todo.progressTask(1, { from: a_creator }), 'Task does not exist');
			await expectRevert(todo.delegateTask(1, a_delegate, { from: a_creator }), 'Task does not exist');
		});

		it('revert when sender is not authorized', async function() {
			await todo.createTask(taskText, a_mate, one, { from: a_creator });
			await expectTaskStatus(0, Statuses.Created);
			await expectRevert(todo.progressTask(0, { from: a_stranger }), 'Sender is not creator or delegate');
		});

		it('should not allow updates to a completed task', async function() {
			let taskId = (await todo.createTask(taskText, a_mate, one, { from: a_creator })).logs[0].args.taskId;
			await todo.progressTask(taskId, { from: a_creator });
			await todo.progressTask(taskId, { from: a_creator });

			await expectRevert(todo.progressTask(taskId, { from: a_creator }), 'Task already complete');
			await expectRevert(todo.delegateTask(taskId, a_delegate, { from: a_creator }), 'Cannot delegate once started');
		});
	});

	describe('Delegation', function() {
		it('task can be delegated', async function() {
			let taskId = (await todo.createTask(taskText, a_mate, one, { from: a_creator })).logs[0].args.taskId;
			await todo.delegateTask(taskId, a_delegate, { from: a_creator });

			expect(todo.isTaskDelegate.call(taskId, { from: a_delegate })).to.eventually.be.true;
		});

		it('only creator can delegate', async function() {
			let taskId = (await todo.createTask(taskText, a_mate, one, { from: a_creator })).logs[0].args.taskId;

			await expectRevert(todo.delegateTask(taskId, a_stranger, { from: a_delegate }), 'Sender is not creator');
			await expectRevert(todo.delegateTask(taskId, a_delegate, { from: a_delegate }), 'Sender is not creator'); // modifier precedence
		});

		it('creator should not be delegate', async function() {
			let taskId = (await todo.createTask(taskText, a_mate, one, { from: a_creator })).logs[0].args.taskId;
			todo.delegateTask(taskId, a_delegate, { from: a_creator });
			await expectRevert(todo.delegateTask(taskId, a_creator, { from: a_creator }), 'Creator cannot be delegate');
		});

		it('should not be able to delegate if pending or completed', async function() {
			let taskId = (await todo.createTask(taskText, a_mate, one, { from: a_creator })).logs[0].args.taskId;
			await todo.progressTask(taskId, { from: a_creator });
			await expectRevert(todo.delegateTask(taskId, a_delegate, { from: a_creator }), 'Cannot delegate once started');
		});
	});
	describe('Staking', function() {
		it('should allow no stake', async function() {
			await todo.createTask(taskText, a_mate, one, { from: a_creator, value: 0 });
		});

		it('should ', async function() {});

		it('', async function() {});
	});

	describe('Scale', function() {
		let stressLoad = 50; // make this bigger if you have beans to brew

		it(`should handle ${stressLoad} tasks`, async function() {
			this.skip();
			this.timeout(15000);
			for (let i = 0; i < stressLoad; i++) {
				await todo.createTask(`task_${i.toString().padStart(3)}`, { from: other_accounts[i] });
			}

			const completeAllTasks = [];

			// Move all the tasks through each state
			// - using promise chains to make transaction ordering more chaotic
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

	// @TODO
	describe('staked tasks', function() {});

	describe('timed tasks', function() {});
});
