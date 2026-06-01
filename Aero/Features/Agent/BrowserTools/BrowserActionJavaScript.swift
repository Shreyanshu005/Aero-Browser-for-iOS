import Foundation

enum BrowserActionJavaScript {
    static let elementIDAttribute = "data-aero-element-id"

    static func clickElement(id: BrowserElementID, userApproved: Bool) -> String {
        elementScript(action: "click", elementID: id.rawValue, text: nil, userApproved: userApproved)
    }

    static func typeText(id: BrowserElementID?, text: String) -> String {
        elementScript(action: "typeText", elementID: id?.rawValue, text: text, userApproved: true)
    }

    static func clearField(id: BrowserElementID?) -> String {
        elementScript(action: "clearField", elementID: id?.rawValue, text: nil, userApproved: true)
    }

    static func pressEnter(id: BrowserElementID?, userApproved: Bool) -> String {
        elementScript(action: "pressEnter", elementID: id?.rawValue, text: nil, userApproved: userApproved)
    }

    static func scroll(_ request: BrowserScrollRequest) -> String {
        let direction = javaScriptLiteral(request.direction.rawValue)
        let amount = request.amount.map { String($0) } ?? "null"

        return """
        JSON.stringify((function() {
          const direction = \(direction);
          const requestedAmount = \(amount);

          function scrollState() {
            const root = document.scrollingElement || document.documentElement;
            return {
              x: window.scrollX || root.scrollLeft || 0,
              y: window.scrollY || root.scrollTop || 0,
              contentWidth: Math.max(root.scrollWidth || 0, document.body ? document.body.scrollWidth : 0),
              contentHeight: Math.max(root.scrollHeight || 0, document.body ? document.body.scrollHeight : 0),
              viewportWidth: window.innerWidth || root.clientWidth || 0,
              viewportHeight: window.innerHeight || root.clientHeight || 0
            };
          }

          const before = scrollState();
          const fallbackAmount = direction === "left" || direction === "right"
            ? Math.max(1, before.viewportWidth * 0.75)
            : Math.max(1, before.viewportHeight * 0.75);
          const amount = Math.max(1, Number(requestedAmount || fallbackAmount));
          const delta = {
            left: [-amount, 0],
            right: [amount, 0],
            up: [0, -amount],
            down: [0, amount]
          }[direction];

          if (!delta) {
            return {
              ok: false,
              code: "invalidRequest",
              message: "Unsupported scroll direction.",
              element: null,
              scroll: before
            };
          }

          window.scrollBy({ left: delta[0], top: delta[1], behavior: "auto" });

          return {
            ok: true,
            code: "success",
            message: "Scrolled page.",
            element: null,
            scroll: scrollState()
          };
        })())
        """
    }

    private static func elementScript(
        action: String,
        elementID: String?,
        text: String?,
        userApproved: Bool
    ) -> String {
        let actionLiteral = javaScriptLiteral(action)
        let elementIDLiteral = elementID.map(javaScriptLiteral) ?? "null"
        let textLiteral = text.map(javaScriptLiteral) ?? "null"
        let approvedLiteral = userApproved ? "true" : "false"
        let attributeLiteral = javaScriptLiteral(elementIDAttribute)

        return """
        JSON.stringify((function() {
          const action = \(actionLiteral);
          const targetID = \(elementIDLiteral);
          const text = \(textLiteral);
          const userApproved = \(approvedLiteral);
          const elementIDAttribute = \(attributeLiteral);

          function result(ok, code, message, element, scroll) {
            return {
              ok: ok,
              code: code,
              message: message,
              element: element || null,
              scroll: scroll || null
            };
          }

          function findByElementID(id) {
            const candidates = document.querySelectorAll("[" + elementIDAttribute + "]");
            for (let index = 0; index < candidates.length; index += 1) {
              const candidate = candidates[index];
              if (candidate.getAttribute(elementIDAttribute) === id) {
                return candidate;
              }
            }
            return null;
          }

          function targetElement() {
            if (targetID !== null && targetID !== undefined && String(targetID).length > 0) {
              return findByElementID(String(targetID));
            }
            const active = document.activeElement;
            if (!active || active === document.body || active === document.documentElement) {
              return null;
            }
            return active;
          }

          function visible(element) {
            if (!element || !element.getBoundingClientRect) {
              return false;
            }
            const style = window.getComputedStyle(element);
            if (!style || style.visibility === "hidden" || style.display === "none" || Number(style.opacity) === 0) {
              return false;
            }
            const rect = element.getBoundingClientRect();
            return rect.width > 0 && rect.height > 0;
          }

          function disabled(element) {
            return !!(
              element.disabled ||
              element.getAttribute("aria-disabled") === "true" ||
              element.closest("[disabled], [aria-disabled='true']")
            );
          }

          function labelFor(element) {
            const aria = element.getAttribute("aria-label");
            if (aria) {
              return aria.trim().slice(0, 120);
            }

            const labelledBy = element.getAttribute("aria-labelledby");
            if (labelledBy) {
              const label = labelledBy
                .split(/\\s+/)
                .map(function(id) { return document.getElementById(id); })
                .filter(Boolean)
                .map(function(node) { return node.innerText || node.textContent || ""; })
                .join(" ")
                .trim();
              if (label) {
                return label.slice(0, 120);
              }
            }

            const textValue = element.innerText || element.textContent || element.value || element.placeholder || "";
            return String(textValue).trim().replace(/\\s+/g, " ").slice(0, 120);
          }

          function approvalNeeded(element) {
            const tag = element.tagName ? element.tagName.toLowerCase() : "";
            const role = (element.getAttribute("role") || "").toLowerCase();
            const type = (element.getAttribute("type") || "").toLowerCase();
            const label = labelFor(element).toLowerCase();
            const keywords = /(buy|purchase|order|pay|delete|remove|sign in|login|log in|submit|send|post|share|upload|download)/;

            if ((tag === "button" || role === "button") && keywords.test(label)) {
              return true;
            }
            if (tag === "input" && ["submit", "button", "image"].includes(type) && keywords.test(label || type)) {
              return true;
            }
            if ((tag === "button" || tag === "input") && type === "submit") {
              return true;
            }
            if (action === "pressEnter") {
              const form = element.form || element.closest("form");
              if (form && String(form.method || "get").toLowerCase() === "post") {
                return true;
              }
            }
            return false;
          }

          function summary(element) {
            return {
              elementID: element.getAttribute(elementIDAttribute) || null,
              tagName: element.tagName ? element.tagName.toLowerCase() : null,
              role: element.getAttribute("role"),
              type: element.getAttribute("type"),
              label: labelFor(element),
              isVisible: visible(element),
              isDisabled: disabled(element),
              requiresApproval: approvalNeeded(element)
            };
          }

          function isEditable(element) {
            const tag = element.tagName ? element.tagName.toLowerCase() : "";
            return tag === "input" || tag === "textarea" || element.isContentEditable;
          }

          function setNativeValue(element, newValue) {
            const tag = element.tagName ? element.tagName.toLowerCase() : "";
            let setter = null;
            if (tag === "input") {
                const desc = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, "value");
                if (desc) setter = desc.set;
            } else if (tag === "textarea") {
                const desc = Object.getOwnPropertyDescriptor(window.HTMLTextAreaElement.prototype, "value");
                if (desc) setter = desc.set;
            }
            if (setter) {
                setter.call(element, newValue);
            } else {
                element.value = newValue;
            }
          }

          function dispatchFieldEvents(element) {
            element.dispatchEvent(new KeyboardEvent("keydown", { bubbles: true, key: "Unidentified" }));
            element.dispatchEvent(new KeyboardEvent("keypress", { bubbles: true, key: "Unidentified" }));
            element.dispatchEvent(new InputEvent("input", { bubbles: true, inputType: "insertText", data: text || "" }));
            element.dispatchEvent(new KeyboardEvent("keyup", { bubbles: true, key: "Unidentified" }));
            element.dispatchEvent(new Event("change", { bubbles: true }));
          }

          function insertText(element, value) {
            const tag = element.tagName ? element.tagName.toLowerCase() : "";
            element.focus();

            if (tag === "input" || tag === "textarea") {
              const currentValue = String(element.value || "");
              const start = typeof element.selectionStart === "number" ? element.selectionStart : currentValue.length;
              const end = typeof element.selectionEnd === "number" ? element.selectionEnd : currentValue.length;
              const newValue = currentValue.slice(0, start) + value + currentValue.slice(end);
              
              setNativeValue(element, newValue);
              dispatchFieldEvents(element);
              return true;
            }

            if (element.isContentEditable) {
              const inserted = document.execCommand && document.execCommand("insertText", false, value);
              if (!inserted) {
                element.textContent = String(element.textContent || "") + value;
                dispatchFieldEvents(element);
              }
              return true;
            }

            return false;
          }

          function clearEditable(element) {
            const tag = element.tagName ? element.tagName.toLowerCase() : "";
            element.focus();

            if (tag === "input" || tag === "textarea") {
              setNativeValue(element, "");
              dispatchFieldEvents(element);
              return true;
            }

            if (element.isContentEditable) {
              element.textContent = "";
              dispatchFieldEvents(element);
              return true;
            }

            return false;
          }

          const element = targetElement();
          if (!element) {
            return result(false, "elementMissing", targetID ? "Element ID is stale or missing." : "No focused element is available.", null, null);
          }

          const elementSummary = summary(element);
          if (!elementSummary.isVisible || elementSummary.isDisabled) {
            return result(false, "elementNotInteractable", "Element is not currently interactable.", elementSummary, null);
          }

          if ((action === "click" || action === "pressEnter") && elementSummary.requiresApproval && !userApproved) {
            return result(false, "approvalRequired", "Action may submit or share data and needs approval.", elementSummary, null);
          }

          element.scrollIntoView({ block: "center", inline: "center", behavior: "auto" });
          element.focus();

          if (action === "click") {
            element.click();
            return result(true, "success", "Clicked element.", summary(element), null);
          }

          if (action === "typeText") {
            if (!isEditable(element) || !insertText(element, String(text || ""))) {
              return result(false, "elementNotInteractable", "Target element cannot receive text.", summary(element), null);
            }
            return result(true, "success", "Typed text.", summary(element), null);
          }

          if (action === "clearField") {
            if (!isEditable(element) || !clearEditable(element)) {
              return result(false, "elementNotInteractable", "Target element cannot be cleared.", summary(element), null);
            }
            return result(true, "success", "Cleared field.", summary(element), null);
          }

          if (action === "pressEnter") {
            const eventInit = {
              key: "Enter",
              code: "Enter",
              keyCode: 13,
              which: 13,
              bubbles: true,
              cancelable: true
            };
            const keydownAllowed = element.dispatchEvent(new KeyboardEvent("keydown", eventInit));
            const keypressAllowed = element.dispatchEvent(new KeyboardEvent("keypress", eventInit));
            if (keydownAllowed && keypressAllowed) {
              const form = element.form || element.closest("form");
              if (form && typeof form.requestSubmit === "function") {
                form.requestSubmit();
              } else if (form) {
                form.submit();
              } else if (element.tagName && element.tagName.toLowerCase() === "textarea") {
                insertText(element, "\\n");
              }
            }
            element.dispatchEvent(new KeyboardEvent("keyup", eventInit));
            return result(true, "success", "Pressed Enter.", summary(element), null);
          }

          return result(false, "invalidRequest", "Unsupported element action.", elementSummary, null);
        })())
        """
    }

    private static func javaScriptLiteral(_ value: String) -> String {
        guard
            let data = try? JSONSerialization.data(withJSONObject: [value], options: []),
            let array = String(data: data, encoding: .utf8)
        else {
            return "\"\""
        }

        return String(array.dropFirst().dropLast())
    }
}
