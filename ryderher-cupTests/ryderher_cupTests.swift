//
//  ryderher_cupTests.swift
//  ryderher-cupTests
//
//  Created by Jonas Peek on 3/28/26.
//

import Testing
@testable import ryderher_cup

struct ryderher_cupTests {

  @Test func shortLastNameUsesInitialWhenLastNamesCollide() {
    let field = ["Tyler Schmalz", "Dylan Schmalz", "Jonas Peek"]
    #expect(PlayerNameFormatting.shortLastName("Tyler Schmalz", among: field) == "T. Schmalz")
    #expect(PlayerNameFormatting.shortLastName("Dylan Schmalz", among: field) == "D. Schmalz")
    #expect(PlayerNameFormatting.shortLastName("Jonas Peek", among: field) == "Peek")
  }

  @Test func shortLastNameStaysPlainWhenUnique() {
    let field = ["Jonas Peek", "Tyler Schmalz", "Erik Sarier"]
    #expect(PlayerNameFormatting.shortLastName("Tyler Schmalz", among: field) == "Schmalz")
  }
}
