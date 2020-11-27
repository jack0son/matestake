const TaskLib = artifacts.require('TaskLib');
const Helpers = artifacts.require('Helpers');
const Todo = artifacts.require('Todo');

module.exports = function(deployer) {
	deployer.deploy(TaskLib);
	deployer.link(TaskLib, Todo);

	deployer.deploy(Helpers);
	deployer.link(Helpers, Todo);

	deployer.deploy(Todo);
};
