import Foundation
import WebKit

enum PageObservationServiceError: Error, Equatable, LocalizedError {
    case missingWebView
    case invalidJavaScriptResult

    var errorDescription: String? {
        switch self {
        case .missingWebView:
            return "No active web view is available to observe."
        case .invalidJavaScriptResult:
            return "Page observation returned an invalid JavaScript result."
        }
    }
}

struct PageObservationService {
    @MainActor
    func observe(webView: WKWebView?) async throws -> PageObservation {
        guard let webView else {
            throw PageObservationServiceError.missingWebView
        }

        let json = try await evaluateObservationJavaScript(in: webView)
        return try Self.decodeObservation(from: json)
    }

    static func decodeObservation(from json: String, observedAt: Date = Date()) throws -> PageObservation {
        let payload = try JSONDecoder().decode(PageObservationPayload.self, from: Data(json.utf8))
        return sanitizedObservation(from: payload, observedAt: observedAt)
    }

    @MainActor
    private func evaluateObservationJavaScript(in webView: WKWebView) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            webView.evaluateJavaScript(Self.observationJavaScript) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let json = result as? String else {
                    continuation.resume(throwing: PageObservationServiceError.invalidJavaScriptResult)
                    return
                }

                continuation.resume(returning: json)
            }
        }
    }

    private static func sanitizedObservation(
        from payload: PageObservationPayload,
        observedAt: Date
    ) -> PageObservation {
        let links = (payload.links ?? [])
            .prefix(PageObservationLimits.maxLinks)
            .map(sanitizedLink)
        let buttons = (payload.buttons ?? [])
            .prefix(PageObservationLimits.maxButtons)
            .map(sanitizedButton)
        let inputs = (payload.inputs ?? [])
            .prefix(PageObservationLimits.maxInputs)
            .map(sanitizedInput)
        let forms = (payload.forms ?? [])
            .prefix(PageObservationLimits.maxForms)
            .map(sanitizedForm)
        let elements = (payload.elements ?? [])
            .prefix(PageObservationLimits.maxElements)
            .map(sanitizedElement)

        return PageObservation(
            url: limitedOptional(payload.url, limit: PageObservationLimits.maxURLCharacters),
            title: cleanHumanText(payload.title ?? "", limit: PageObservationLimits.maxShortTextCharacters),
            visibleTextSummary: cleanHumanText(
                payload.visibleTextSummary ?? "",
                limit: PageObservationLimits.maxVisibleTextSummaryCharacters
            ),
            links: links,
            buttons: buttons,
            inputs: inputs,
            forms: forms,
            scroll: payload.scroll ?? PageScrollMetrics(),
            elements: elements,
            observedAt: observedAt
        )
    }

    private static func sanitizedLink(_ link: PageObservedLink) -> PageObservedLink {
        PageObservedLink(
            targetID: limited(link.targetID, limit: PageObservationLimits.maxTargetIDCharacters),
            targetPath: limited(link.targetPath, limit: PageObservationLimits.maxTargetPathCharacters),
            text: cleanHumanText(link.text, limit: PageObservationLimits.maxElementTextCharacters),
            url: limitedOptional(link.url, limit: PageObservationLimits.maxURLCharacters),
            title: cleanHumanTextOptional(link.title, limit: PageObservationLimits.maxShortTextCharacters),
            ariaLabel: cleanHumanTextOptional(link.ariaLabel, limit: PageObservationLimits.maxShortTextCharacters)
        )
    }

    private static func sanitizedButton(_ button: PageObservedButton) -> PageObservedButton {
        PageObservedButton(
            targetID: limited(button.targetID, limit: PageObservationLimits.maxTargetIDCharacters),
            targetPath: limited(button.targetPath, limit: PageObservationLimits.maxTargetPathCharacters),
            text: cleanHumanText(button.text, limit: PageObservationLimits.maxElementTextCharacters),
            type: cleanHumanTextOptional(button.type, limit: PageObservationLimits.maxShortTextCharacters),
            name: cleanHumanTextOptional(button.name, limit: PageObservationLimits.maxShortTextCharacters),
            ariaLabel: cleanHumanTextOptional(button.ariaLabel, limit: PageObservationLimits.maxShortTextCharacters),
            isDisabled: button.isDisabled
        )
    }

    private static func sanitizedInput(_ input: PageObservedInput) -> PageObservedInput {
        PageObservedInput(
            targetID: limited(input.targetID, limit: PageObservationLimits.maxTargetIDCharacters),
            targetPath: limited(input.targetPath, limit: PageObservationLimits.maxTargetPathCharacters),
            label: cleanHumanText(input.label, limit: PageObservationLimits.maxShortTextCharacters),
            type: cleanHumanText(input.type, limit: PageObservationLimits.maxShortTextCharacters),
            name: cleanHumanTextOptional(input.name, limit: PageObservationLimits.maxShortTextCharacters),
            placeholder: cleanHumanTextOptional(input.placeholder, limit: PageObservationLimits.maxShortTextCharacters),
            value: cleanHumanTextOptional(input.value, limit: PageObservationLimits.maxInputValueCharacters),
            isRequired: input.isRequired,
            isDisabled: input.isDisabled,
            isSearchField: input.isSearchField
        )
    }

    private static func sanitizedForm(_ form: PageObservedForm) -> PageObservedForm {
        PageObservedForm(
            targetID: limited(form.targetID, limit: PageObservationLimits.maxTargetIDCharacters),
            targetPath: limited(form.targetPath, limit: PageObservationLimits.maxTargetPathCharacters),
            label: cleanHumanText(form.label, limit: PageObservationLimits.maxShortTextCharacters),
            action: limitedOptional(form.action, limit: PageObservationLimits.maxURLCharacters),
            method: cleanHumanText(form.method, limit: PageObservationLimits.maxShortTextCharacters),
            fieldTargetIDs: form.fieldTargetIDs
                .prefix(PageObservationLimits.maxFormFields)
                .map { limited($0, limit: PageObservationLimits.maxTargetIDCharacters) },
            searchFieldTargetIDs: form.searchFieldTargetIDs
                .prefix(PageObservationLimits.maxFormFields)
                .map { limited($0, limit: PageObservationLimits.maxTargetIDCharacters) }
        )
    }

    private static func sanitizedElement(_ element: PageObservedElement) -> PageObservedElement {
        PageObservedElement(
            targetID: limited(element.targetID, limit: PageObservationLimits.maxTargetIDCharacters),
            targetPath: limited(element.targetPath, limit: PageObservationLimits.maxTargetPathCharacters),
            kind: element.kind,
            label: cleanHumanText(element.label, limit: PageObservationLimits.maxShortTextCharacters),
            text: cleanHumanTextOptional(element.text, limit: PageObservationLimits.maxElementTextCharacters),
            isEnabled: element.isEnabled,
            tagName: cleanHumanTextOptional(element.tagName, limit: PageObservationLimits.maxShortTextCharacters),
            role: cleanHumanTextOptional(element.role, limit: PageObservationLimits.maxShortTextCharacters),
            className: cleanHumanTextOptional(element.className, limit: PageObservationLimits.maxShortTextCharacters),
            dataTestID: cleanHumanTextOptional(element.dataTestID, limit: PageObservationLimits.maxShortTextCharacters)
        )
    }

    private static func cleanHumanText(_ value: String, limit: Int) -> String {
        let normalized = value
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return limited(normalized, limit: limit)
    }

    private static func cleanHumanTextOptional(_ value: String?, limit: Int) -> String? {
        guard let cleaned = value.map({ cleanHumanText($0, limit: limit) }), !cleaned.isEmpty else {
            return nil
        }
        return cleaned
    }

    private static func limitedOptional(_ value: String?, limit: Int) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return limited(trimmed, limit: limit)
    }

    private static func limited(_ value: String, limit: Int) -> String {
        guard value.count > limit else { return value }
        return String(value.prefix(limit))
    }
}

private struct PageObservationPayload: Decodable {
    var url: String?
    var title: String?
    var visibleTextSummary: String?
    var links: [PageObservedLink]?
    var buttons: [PageObservedButton]?
    var inputs: [PageObservedInput]?
    var forms: [PageObservedForm]?
    var scroll: PageScrollMetrics?
    var elements: [PageObservedElement]?
}

extension PageObservationService {
    static let observationJavaScript = """
    (function() {
      const limits = {
        visibleTextSummary: \(PageObservationLimits.maxVisibleTextSummaryCharacters),
        elementText: \(PageObservationLimits.maxElementTextCharacters),
        shortText: \(PageObservationLimits.maxShortTextCharacters),
        inputValue: \(PageObservationLimits.maxInputValueCharacters),
        url: \(PageObservationLimits.maxURLCharacters),
        targetPath: \(PageObservationLimits.maxTargetPathCharacters),
        links: \(PageObservationLimits.maxLinks),
        buttons: \(PageObservationLimits.maxButtons),
        inputs: \(PageObservationLimits.maxInputs),
        forms: \(PageObservationLimits.maxForms),
        elements: \(PageObservationLimits.maxElements),
        formFields: \(PageObservationLimits.maxFormFields),
        textPieces: 160,
        textNodesVisited: 5000
      };

      const elementIDAttribute = '\(BrowserActionJavaScript.elementIDAttribute)';
      const viewportWidth = Math.max(document.documentElement.clientWidth || 0, window.innerWidth || 0);
      const viewportHeight = Math.max(document.documentElement.clientHeight || 0, window.innerHeight || 0);

      function normalizeText(value) {
        return String(value || '').replace(/\\s+/g, ' ').trim();
      }

      function limitText(value, limit) {
        const text = normalizeText(value);
        return text.length > limit ? text.slice(0, limit) : text;
      }

      function limitRaw(value, limit) {
        if (value === null || value === undefined) return null;
        const text = String(value).trim();
        if (!text) return null;
        return text.length > limit ? text.slice(0, limit) : text;
      }

      function rectIntersectsViewport(rect) {
        return rect &&
          rect.width > 0 &&
          rect.height > 0 &&
          rect.bottom > 0 &&
          rect.right > 0 &&
          rect.top < viewportHeight &&
          rect.left < viewportWidth;
      }

      function elementIntersectsViewport(element) {
        if (!element || element.nodeType !== Node.ELEMENT_NODE) return false;
        const rects = element.getClientRects();
        for (let index = 0; index < rects.length; index += 1) {
          if (rectIntersectsViewport(rects[index])) return true;
        }
        return false;
      }

      function isVisibleElement(element) {
        if (!element || element.nodeType !== Node.ELEMENT_NODE) return false;
        const style = window.getComputedStyle(element);
        if (!style || style.display === 'none' || style.visibility === 'hidden' || style.visibility === 'collapse') {
          return false;
        }
        if (Number(style.opacity) === 0) return false;
        return elementIntersectsViewport(element);
      }

      function textNodeIntersectsViewport(node) {
        let range = null;
        try {
          range = document.createRange();
          range.selectNodeContents(node);
          const rects = range.getClientRects();
          for (let index = 0; index < rects.length; index += 1) {
            if (rectIntersectsViewport(rects[index])) return true;
          }
        } catch (error) {
          return false;
        } finally {
          if (range && range.detach) range.detach();
        }
        return false;
      }

      function targetPathFor(element) {
        const parts = [];
        let current = element;
        while (current && current.nodeType === Node.ELEMENT_NODE) {
          const tag = current.tagName.toLowerCase();
          let nth = 1;
          let sibling = current.previousElementSibling;
          while (sibling) {
            if (sibling.tagName === current.tagName) nth += 1;
            sibling = sibling.previousElementSibling;
          }
          parts.unshift(tag + ':nth-of-type(' + nth + ')');
          if (current === document.documentElement) break;
          current = current.parentElement;
        }
        return limitRaw(parts.join('>'), limits.targetPath) || '';
      }

      function fnv1aBase36(value) {
        let hash = 0x811c9dc5;
        for (let index = 0; index < value.length; index += 1) {
          hash ^= value.charCodeAt(index);
          hash = Math.imul(hash, 0x01000193) >>> 0;
        }
        return hash.toString(36);
      }

      function targetID(kind, path) {
        return 'aero-v1:' + kind + ':' + fnv1aBase36(path);
      }

      function targetFor(element, kind) {
        const path = targetPathFor(element);
        const id = targetID(kind, path);
        element.setAttribute(elementIDAttribute, id);
        return {
          targetID: id,
          targetPath: path
        };
      }

      function absoluteURL(value) {
        if (!value) return null;
        try {
          return new URL(value, document.baseURI).href;
        } catch (error) {
          return String(value);
        }
      }

      function textFromLabelledBy(element) {
        const labelledBy = element.getAttribute('aria-labelledby');
        if (!labelledBy) return '';
        return labelledBy
          .split(/\\s+/)
          .map(function(id) {
            const label = document.getElementById(id);
            return label ? label.textContent : '';
          })
          .join(' ');
      }

      function labelsForControl(element) {
        if (!element.labels || !element.labels.length) return '';
        return Array.from(element.labels)
          .map(function(label) { return label.textContent || ''; })
          .join(' ');
      }

      function inputLabel(element) {
        return limitText(
          element.getAttribute('aria-label') ||
          textFromLabelledBy(element) ||
          labelsForControl(element) ||
          (element.closest('label') ? element.closest('label').textContent : '') ||
          element.getAttribute('placeholder') ||
          element.getAttribute('title') ||
          element.getAttribute('name') ||
          element.getAttribute('id') ||
          '',
          limits.shortText
        );
      }

      function elementLabel(element) {
        return limitText(
          element.getAttribute('aria-label') ||
          textFromLabelledBy(element) ||
          element.innerText ||
          element.textContent ||
          element.getAttribute('title') ||
          element.getAttribute('name') ||
          element.getAttribute('id') ||
          '',
          limits.shortText
        );
      }

      function isButtonElement(element) {
        if (!element || !element.tagName) return false;
        const tag = element.tagName.toLowerCase();
        const role = (element.getAttribute('role') || '').toLowerCase();
        const type = (element.getAttribute('type') || '').toLowerCase();
        return tag === 'button' ||
          role === 'button' ||
          (tag === 'input' && ['button', 'submit', 'reset', 'image'].includes(type));
      }

      function isEditableInput(element) {
        if (!element || !element.tagName) return false;
        const tag = element.tagName.toLowerCase();
        const role = (element.getAttribute('role') || '').toLowerCase();
        const type = (element.getAttribute('type') || '').toLowerCase();
        if (tag === 'textarea' || tag === 'select') return true;
        if (element.isContentEditable || role === 'textbox' || role === 'searchbox') return true;
        if (tag !== 'input') return false;
        return !['hidden', 'button', 'submit', 'reset', 'image', 'file'].includes(type);
      }

      function inputType(element) {
        const tag = element.tagName.toLowerCase();
        if (tag === 'textarea' || tag === 'select') return tag;
        if (element.isContentEditable) return 'contenteditable';
        return (element.getAttribute('type') || 'text').toLowerCase();
      }

      function isDisabled(element) {
        return Boolean(element.disabled || element.getAttribute('aria-disabled') === 'true');
      }

      function isSearchField(element) {
        const haystack = [
          inputType(element),
          element.getAttribute('role'),
          element.getAttribute('name'),
          element.getAttribute('id'),
          element.getAttribute('placeholder'),
          element.getAttribute('aria-label'),
          textFromLabelledBy(element)
        ].join(' ').toLowerCase();
        return haystack.includes('search');
      }

      function safeInputValue(element, type) {
        if (type === 'password') return null;
        if (element.isContentEditable) return limitText(element.textContent, limits.inputValue);
        return limitText(element.value || '', limits.inputValue);
      }

      function dataTestID(element) {
        return limitText(
          element.getAttribute('data-testid') ||
          element.getAttribute('data-test-id') ||
          element.getAttribute('data-test') ||
          '',
          limits.shortText
        ) || null;
      }

      function elementMetadata(element) {
        return {
          tagName: element.tagName ? element.tagName.toLowerCase() : null,
          role: limitText(element.getAttribute('role') || '', limits.shortText) || null,
          className: limitText(element.getAttribute('class') || '', limits.shortText) || null,
          dataTestID: dataTestID(element)
        };
      }

      function linkRecord(element) {
        const target = targetFor(element, 'link');
        return {
          targetID: target.targetID,
          targetPath: target.targetPath,
          text: limitText(
            element.innerText ||
            element.textContent ||
            element.getAttribute('aria-label') ||
            element.getAttribute('title') ||
            element.href ||
            '',
            limits.elementText
          ),
          url: limitRaw(element.href || absoluteURL(element.getAttribute('href')), limits.url),
          title: limitText(element.getAttribute('title') || '', limits.shortText) || null,
          ariaLabel: limitText(element.getAttribute('aria-label') || '', limits.shortText) || null
        };
      }

      function buttonRecord(element) {
        const target = targetFor(element, 'button');
        const type = (element.getAttribute('type') || '').toLowerCase();
        return {
          targetID: target.targetID,
          targetPath: target.targetPath,
          text: limitText(element.value || elementLabel(element), limits.elementText),
          type: type || null,
          name: limitText(element.getAttribute('name') || '', limits.shortText) || null,
          ariaLabel: limitText(element.getAttribute('aria-label') || '', limits.shortText) || null,
          isDisabled: isDisabled(element)
        };
      }

      function inputRecord(element) {
        const target = targetFor(element, 'input');
        const type = inputType(element);
        return {
          targetID: target.targetID,
          targetPath: target.targetPath,
          label: inputLabel(element),
          type: type,
          name: limitText(element.getAttribute('name') || '', limits.shortText) || null,
          placeholder: limitText(element.getAttribute('placeholder') || '', limits.shortText) || null,
          value: safeInputValue(element, type) || null,
          isRequired: Boolean(element.required || element.getAttribute('aria-required') === 'true'),
          isDisabled: isDisabled(element),
          isSearchField: isSearchField(element)
        };
      }

      function formRecord(element) {
        const target = targetFor(element, 'form');
        const fields = Array.from(element.querySelectorAll('input, textarea, select, [contenteditable="true"], [role="textbox"], [role="searchbox"]'))
          .filter(function(field) { return isEditableInput(field) && isVisibleElement(field); })
          .slice(0, limits.formFields);
        const fieldTargets = fields.map(function(field) {
          return {
            field: field,
            target: targetFor(field, 'input')
          };
        });
        const fieldTargetIDs = fieldTargets.map(function(item) { return item.target.targetID; });
        const searchFieldTargetIDs = fieldTargets
          .filter(function(item) { return isSearchField(item.field); })
          .map(function(item) { return item.target.targetID; });

        return {
          targetID: target.targetID,
          targetPath: target.targetPath,
          label: limitText(
            element.getAttribute('aria-label') ||
            textFromLabelledBy(element) ||
            element.getAttribute('name') ||
            element.getAttribute('id') ||
            '',
            limits.shortText
          ),
          action: limitRaw(absoluteURL(element.getAttribute('action') || document.location.href), limits.url),
          method: limitText((element.getAttribute('method') || 'GET').toUpperCase(), limits.shortText),
          fieldTargetIDs: fieldTargetIDs,
          searchFieldTargetIDs: searchFieldTargetIDs
        };
      }

      function visibleTextSummary() {
        if (!document.body) return '';
        const pieces = [];
        const ignoredSelector = 'script, style, noscript, svg, canvas, template';
        const walker = document.createTreeWalker(
          document.body,
          NodeFilter.SHOW_TEXT,
          {
            acceptNode: function(node) {
              const parent = node.parentElement;
              if (!parent || parent.closest(ignoredSelector)) return NodeFilter.FILTER_REJECT;
              const text = normalizeText(node.nodeValue);
              if (!text) return NodeFilter.FILTER_REJECT;
              return NodeFilter.FILTER_ACCEPT;
            }
          }
        );

        let visited = 0;
        let node = walker.nextNode();
        while (node && pieces.length < limits.textPieces && visited < limits.textNodesVisited) {
          visited += 1;
          const parent = node.parentElement;
          if (parent && isVisibleElement(parent) && textNodeIntersectsViewport(node)) {
            pieces.push(normalizeText(node.nodeValue));
          }
          node = walker.nextNode();
        }

        return limitText(pieces.join(' '), limits.visibleTextSummary);
      }

      function isExtractionCandidate(element) {
        const tag = element.tagName ? element.tagName.toLowerCase() : '';
        const role = (element.getAttribute('role') || '').toLowerCase();
        if (tag === 'article' || role === 'article' || role === 'listitem') return true;

        const tokens = [
          'product',
          'product-card',
          'product-tile',
          'listing',
          'sku',
          'item-card',
          'search-result',
          'serp-result',
          'organic-result',
          'web-result',
          'post',
          'tweet',
          'status',
          'feed-item',
          'comment',
          'timeline-item'
        ];
        const haystack = [
          element.getAttribute('class'),
          element.getAttribute('id'),
          element.getAttribute('role'),
          element.getAttribute('itemtype'),
          element.getAttribute('itemprop'),
          element.getAttribute('aria-label'),
          element.getAttribute('data-testid'),
          element.getAttribute('data-test-id'),
          element.getAttribute('data-test')
        ]
          .filter(Boolean)
          .join(' ')
          .toLowerCase();

        return tokens.some(function(token) { return haystack.includes(token); });
      }

      function collectElements() {
        const selector = [
          'a[href]',
          'button',
          'input',
          'textarea',
          'select',
          '[role="button"]',
          '[role="textbox"]',
          '[role="searchbox"]',
          '[contenteditable="true"]',
          'form',
          'article',
          '[role="article"]',
          '[role="listitem"]',
          '[data-testid]',
          '[data-test-id]',
          '[data-test]',
          '[itemtype]',
          '[itemprop]',
          '[class*="product"]',
          '[class*="Product"]',
          '[class*="listing"]',
          '[class*="Listing"]',
          '[class*="search-result"]',
          '[class*="SearchResult"]',
          '[class*="serp-result"]',
          '[class*="organic-result"]',
          '[class*="web-result"]',
          '[class*="post"]',
          '[class*="Post"]',
          '[class*="tweet"]',
          '[class*="Tweet"]',
          '[class*="status"]',
          '[class*="Status"]',
          '[class*="feed-item"]',
          '[class*="timeline-item"]'
        ].join(',');
        const records = [];
        const seen = new Set();
        const nodes = Array.from(document.querySelectorAll(selector));

        for (const element of nodes) {
          let kind = null;
          if (element.tagName.toLowerCase() === 'form') {
            kind = 'form';
          } else if (isButtonElement(element)) {
            kind = 'button';
          } else if (isEditableInput(element)) {
            kind = 'input';
          } else if (element.matches('a[href]')) {
            kind = 'link';
          } else if (isExtractionCandidate(element)) {
            kind = 'other';
          }

          if (!kind) continue;
          if (kind !== 'form' && !isVisibleElement(element)) continue;

          const target = targetFor(element, kind);
          if (seen.has(target.targetPath)) continue;
          seen.add(target.targetPath);

          let label = elementLabel(element);
          let text = null;
          let enabled = !isDisabled(element);
          if (kind === 'input') {
            label = inputLabel(element);
          } else if (kind === 'form') {
            const form = formRecord(element);
            if (!isVisibleElement(element) && form.fieldTargetIDs.length === 0) continue;
            label = form.label;
          } else {
            text = limitText(element.innerText || element.textContent || '', limits.elementText) || null;
          }

          const metadata = elementMetadata(element);
          records.push({
            targetID: target.targetID,
            targetPath: target.targetPath,
            kind: kind,
            label: label,
            text: text,
            isEnabled: enabled,
            tagName: metadata.tagName,
            role: metadata.role,
            className: metadata.className,
            dataTestID: metadata.dataTestID
          });

          if (records.length >= limits.elements) break;
        }

        return records;
      }

      const links = Array.from(document.querySelectorAll('a[href]'))
        .filter(function(element) { return !isButtonElement(element) && isVisibleElement(element); })
        .slice(0, limits.links)
        .map(linkRecord);

      const buttons = Array.from(document.querySelectorAll('button, input[type="button"], input[type="submit"], input[type="reset"], input[type="image"], [role="button"]'))
        .filter(function(element) { return isButtonElement(element) && isVisibleElement(element); })
        .slice(0, limits.buttons)
        .map(buttonRecord);

      const inputs = Array.from(document.querySelectorAll('input, textarea, select, [contenteditable="true"], [role="textbox"], [role="searchbox"]'))
        .filter(function(element) { return isEditableInput(element) && isVisibleElement(element); })
        .slice(0, limits.inputs)
        .map(inputRecord);

      const forms = Array.from(document.forms || [])
        .map(formRecord)
        .filter(function(form) { return form.fieldTargetIDs.length > 0 || form.searchFieldTargetIDs.length > 0; })
        .slice(0, limits.forms);

      const contentWidth = Math.max(
        document.documentElement.scrollWidth || 0,
        document.body ? document.body.scrollWidth || 0 : 0,
        viewportWidth
      );
      const contentHeight = Math.max(
        document.documentElement.scrollHeight || 0,
        document.body ? document.body.scrollHeight || 0 : 0,
        viewportHeight
      );

      return JSON.stringify({
        url: limitRaw(document.location.href, limits.url),
        title: limitText(document.title || '', limits.shortText),
        visibleTextSummary: visibleTextSummary(),
        links: links,
        buttons: buttons,
        inputs: inputs,
        forms: forms,
        scroll: {
          scrollX: Number(window.scrollX || window.pageXOffset || 0),
          scrollY: Number(window.scrollY || window.pageYOffset || 0),
          viewportWidth: Number(viewportWidth),
          viewportHeight: Number(viewportHeight),
          contentWidth: Number(contentWidth),
          contentHeight: Number(contentHeight),
          scrollableX: contentWidth > viewportWidth + 1,
          scrollableY: contentHeight > viewportHeight + 1
        },
        elements: collectElements()
      });
    })();
    """
}
