const statusStrings = ["Created", "Pending", "Complete"];

// Build symbol map and list from status strings
const [Statuses, statusList] = statusStrings.reduce(
  ([lut, list], status) => {
    lut[status] = Symbol(status);
    list.push(lut[status]);
    return [lut, list];
  },
  [Object.create(null), []]
);

const Status = (statusInt) => {
  if (statusInt > statusStrings.length)
    throw new Error("Not a valid status enum");
  return statusList[statusInt];
};

const isStatus = (status) => !!status && statusList.includes(status);

module.exports = { statusStrings, Status, Statuses, statusList, isStatus };
