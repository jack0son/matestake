const TaskLib = artifacts.require("TaskLib");
const Todo = artifacts.require("Todo");

module.exports = function(deployer) {
  deployer.deploy(TaskLib);
  deployer.link(TaskLib, Todo);
  deployer.deploy(Todo);
};
