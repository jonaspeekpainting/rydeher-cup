import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { lastName, shortLastName } from "./player-names";

describe("shortLastName", () => {
  it("returns last name when unique among the field", () => {
    const field = ["Jonas Peek", "Tyler Schmalz", "Erik Sarier"];
    assert.equal(shortLastName("Jonas Peek", field), "Peek");
    assert.equal(shortLastName("Tyler Schmalz", field), "Schmalz");
  });

  it("adds first initial when last names collide", () => {
    const field = ["Tyler Schmalz", "Dylan Schmalz", "Jonas Peek"];
    assert.equal(shortLastName("Tyler Schmalz", field), "T. Schmalz");
    assert.equal(shortLastName("Dylan Schmalz", field), "D. Schmalz");
    assert.equal(shortLastName("Jonas Peek", field), "Peek");
  });

  it("is case-insensitive for last-name collisions", () => {
    const field = ["Tyler Schmalz", "dylan schmalz"];
    assert.equal(shortLastName("Tyler Schmalz", field), "T. Schmalz");
  });

  it("falls back to the full string when there is no space", () => {
    assert.equal(shortLastName("Madonna", ["Madonna", "Cher"]), "Madonna");
  });
});

describe("lastName", () => {
  it("returns the final token", () => {
    assert.equal(lastName("Tyler Schmalz"), "Schmalz");
    assert.equal(lastName("  Jonas  Peek  "), "Peek");
  });
});
