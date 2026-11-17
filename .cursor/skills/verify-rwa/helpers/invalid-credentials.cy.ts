import { User } from "../../../../src/models";

const invalidCredentials = "Username or password is invalid";

describe("verify-rwa invalid credentials", function () {
  beforeEach(function () {
    cy.task("db:seed");
  });

  it("shows the auth spec error for an unknown user", function () {
    cy.login("invalidUserName", "invalidPa$$word");

    cy.getBySel("signin-error").should("be.visible").and("have.text", invalidCredentials);
    cy.screenshot("invalid-user-error", { capture: "viewport" });
  });

  it("shows the auth spec error for an existing user and a bad password", function () {
    cy.database("find", "users").then((user: User) => {
      cy.login(user.username, "INVALID");
    });

    cy.getBySel("signin-error").should("be.visible").and("have.text", invalidCredentials);
    cy.screenshot("invalid-password-error", { capture: "viewport" });
  });
});
