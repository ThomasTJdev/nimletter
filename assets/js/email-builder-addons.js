
let
  emailbuilderLoadedJSON = null,
  emailbuilderIdSeq = 0;


const emailbuilderAddonClearJSON = {
  "root": {
    "type": "EmailLayout",
    "data": {
      "backdropColor": "#F5F5F5",
      "canvasColor": "#FFFFFF",
      "textColor": "#262626",
      "fontFamily": "MODERN_SANS",
      "childrenIds": []
    }
  }
};

const emailbuilderDuplicateIconPath = "M16 1H4c-1.1 0-2 .9-2 2v14h2V3h12zm3 4H8c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h11c1.1 0 2-.9 2-2V7c0-1.1-.9-2-2-2m0 16H8V7h11z";

/** Side padding applied on narrow screens to containers marked as the mobile outer layer. */
const emailbuilderMobileOuterPaddingPx = 8;

const emailbuilderMobileOuterCss =
  ".nl-mobile-preview .nl-mobile-outer{padding-left:" + emailbuilderMobileOuterPaddingPx + "px!important;padding-right:" + emailbuilderMobileOuterPaddingPx + "px!important}" +
  "@media only screen and (max-width:620px){.nl-mobile-outer{padding-left:" + emailbuilderMobileOuterPaddingPx + "px!important;padding-right:" + emailbuilderMobileOuterPaddingPx + "px!important}}";


function emailbuilderAddonInit() {
  emailbuilderAddonPatchTuneMenu();
  emailbuilderAddonPatchMobileOuter();
  emailbuilderAddonEnsureMobileOuterStyles();
  emailbuilderAddonSyncMobilePreview();
  emailbuilderAddonWatchUi();
  emailbuilderAddonSavebtn();
  emailbuilderAddonEnsureTree();
  emailbuilderAddonHideSamplesDrawer();
}


function emailbuilderAddonSavebtn() {
  setTimeout(() => {
    const ribbon = dqsA(".MuiStack-root.css-jj2ztu");
    if (ribbon.length < 2) {
      return;
    }
    if (dqs("#saveButton")) {
      return;
    }
    const saveButton = jsRender(jsCreateElement("button", {
      attrs: {
        class: "MuiButtonBase-root MuiButton-root MuiButton-contained MuiButton-containedPrimary",
        id: "saveButton",
        style: "padding: 4px 40px;",
        onclick: "saveMail(" + globalMailData.id + ")"
      },
      children: ["Save"]
    }));
    ribbon[1].prepend(saveButton);


    const closeButton = jsRender(jsCreateElement("button", {
      attrs: {
        class: "MuiButtonBase-root MuiButton-root MuiButton-contained MuiButton-containedPrimary",
        id: "closeButton",
        style: "padding: 4px 40px;",
        onclick: "emailbuilderCloseModal();"
      },
      children: ["Close"]
    }));
    ribbon[1].prepend(closeButton);

  }, 1000);
}


function emailbuilderAddonSetJson(jsonData) {
  try {
    const parsedData = JSON.parse(jsonData);
    Fg(parsedData);
  } catch (error) {
    console.error("Invalid JSON data:", error);
  }
}


function emailbuilderReadDocument() {
  if (typeof Fn !== "undefined" && typeof Fn.getState === "function") {
    try {
      const doc = Fn.getState().document;
      if (doc && doc.root) {
        return doc;
      }
    } catch (error) {
      console.error("Could not read EmailBuilder document:", error);
    }
  }
  return null;
}


function emailbuilderAddonGetJson() {
  const doc = emailbuilderReadDocument();
  let jsonOutput = "";

  if (doc) {
    jsonOutput = JSON.stringify(doc, null, "  ");
  } else {
    const jsonButton = dqs(".MuiButtonBase-root.MuiIconButton-root.MuiIconButton-sizeMedium.css-17kijze[download='emailTemplate.json']");

    // get the JSON. its data:text/plain in the href
    if (jsonButton) {
      const dataUrl = jsonButton.href;
      const base64Data = dataUrl.split(",")[1];
      jsonOutput = decodeURIComponent(base64Data);
    }
  }

  if (dqs(".modalpop")) {
    dqs(".modalpop").classList.remove("hasjson");
  }
  return jsonOutput;
}


function emailbuilderAddonGetHTML() {
  try {
    const jsonStr = emailbuilderAddonGetJson();
    if (!jsonStr) {
      return "";
    }
    let jsonStructure = JSON.parse(jsonStr);
    const html = emailbuilderInternalHTMLBody(jsonStructure, { rootBlockId: 'root' });
    return "<style>" + emailbuilderMobileOuterCss + "</style>" + html;
  } catch (error) {
    console.error("Could not generate HTML from EmailBuilder document:", error);
    return "";
  }
}


function emailbuilderInternalHTMLBody(e, {
  rootBlockId: t
}) {
  return Vde(R.createElement(W6, {
    document: e,
    rootBlockId: t
  }))
}


function emailbuilderInternalHTMLFull(e, {
  rootBlockId: t
}) {
  return "<!DOCTYPE html>" + Vde(R.createElement("html", null, R.createElement("body", null, R.createElement(W6, {
    document: e,
    rootBlockId: t
  }))))
}


function emailbuilderCloseModal() {
  if (JSON.stringify(emailbuilderLoadedJSON) !== JSON.stringify(emailbuilderAddonGetJson())) {
    if (confirm("You have unsaved changes. Quit?")) {
      dqs(".modalpop").classList.remove("show");
    }
  } else {
    dqs(".modalpop").classList.remove("show");
  }
}


function emailbuilderNewBlockId() {
  emailbuilderIdSeq += 1;
  return "block_" + Date.now().toString(36) + emailbuilderIdSeq.toString(36) + Math.random().toString(36).slice(2, 8);
}


function emailbuilderParseSlotIndex(value) {
  if (value === undefined || value === null || value === "" || value === "none") {
    return null;
  }
  const index = parseInt(value, 10);
  return isNaN(index) ? null : index;
}


function emailbuilderReadList(block, columnIndex) {
  if (!block) {
    return [];
  }
  if (typeof columnIndex === "number") {
    const columns = block.data && block.data.props && block.data.props.columns;
    if (!columns || !columns[columnIndex]) {
      return [];
    }
    return columns[columnIndex].childrenIds || [];
  }
  if (block.type === "EmailLayout") {
    return (block.data && block.data.childrenIds) || [];
  }
  if (block.type === "Container") {
    return (block.data && block.data.props && block.data.props.childrenIds) || [];
  }
  return [];
}


function emailbuilderWriteList(block, columnIndex, ids) {
  if (!block) {
    return;
  }
  if (typeof columnIndex === "number") {
    const props = Object.assign({}, block.data.props);
    props.columns = (props.columns || []).map(function (column, index) {
      if (index !== columnIndex) {
        return column;
      }
      return Object.assign({}, column, { childrenIds: ids });
    });
    block.data = Object.assign({}, block.data, { props: props });
    return;
  }
  if (block.type === "EmailLayout") {
    block.data = Object.assign({}, block.data, { childrenIds: ids });
    return;
  }
  if (block.type === "Container") {
    block.data = Object.assign({}, block.data, {
      props: Object.assign({}, block.data.props, { childrenIds: ids })
    });
  }
}


function emailbuilderFindParent(document, blockId) {
  const ids = Object.keys(document);
  for (let i = 0; i < ids.length; i++) {
    const id = ids[i];
    if (id === blockId) {
      continue;
    }
    const block = document[id];
    if (!block) {
      continue;
    }
    if (emailbuilderReadList(block, null).indexOf(blockId) !== -1) {
      return { parentId: id, columnIndex: null };
    }
    const columns = block.data && block.data.props && block.data.props.columns;
    if (Array.isArray(columns)) {
      for (let columnIndex = 0; columnIndex < columns.length; columnIndex++) {
        const childIds = columns[columnIndex].childrenIds || [];
        if (childIds.indexOf(blockId) !== -1) {
          return { parentId: id, columnIndex: columnIndex };
        }
      }
    }
  }
  return null;
}


/**
 * True when maybeId is ancestorId or nested under it. Used to block drops that
 * would parent a block inside one of its own descendants.
 */
function emailbuilderIsDescendant(document, ancestorId, maybeId) {
  if (!ancestorId || !maybeId) {
    return false;
  }
  if (ancestorId === maybeId) {
    return true;
  }
  const seen = {};
  function walk(id) {
    if (!id || seen[id]) {
      return false;
    }
    seen[id] = true;
    if (id === maybeId) {
      return true;
    }
    const block = document[id];
    if (!block) {
      return false;
    }
    const childIds = emailbuilderReadList(block, null);
    for (let i = 0; i < childIds.length; i++) {
      if (walk(childIds[i])) {
        return true;
      }
    }
    const columns = block.data && block.data.props && block.data.props.columns;
    if (Array.isArray(columns)) {
      for (let c = 0; c < columns.length; c++) {
        const nested = columns[c].childrenIds || [];
        for (let i = 0; i < nested.length; i++) {
          if (walk(nested[i])) {
            return true;
          }
        }
      }
    }
    return false;
  }
  return walk(ancestorId);
}


function emailbuilderCanHaveChildren(block) {
  return !!(block && (block.type === "EmailLayout" || block.type === "Container"));
}


/**
 * Move a block by rewriting childrenIds. destIndex is the insertion point in
 * the destination list before the source id is removed.
 */
function emailbuilderDocumentMoveBlock(document, blockId, destParentId, destColumnIndex, destIndex) {
  if (!document || !blockId || blockId === "root" || !document[blockId] || !document[destParentId]) {
    return null;
  }
  if (emailbuilderIsDescendant(document, blockId, destParentId)) {
    return null;
  }

  const destParent = document[destParentId];
  if (typeof destColumnIndex === "number") {
    if (destParent.type !== "ColumnsContainer") {
      return null;
    }
  } else if (!emailbuilderCanHaveChildren(destParent)) {
    return null;
  }

  const source = emailbuilderFindParent(document, blockId);
  if (!source) {
    return null;
  }

  const next = JSON.parse(JSON.stringify(document));
  const sourceIds = emailbuilderReadList(next[source.parentId], source.columnIndex).slice();
  const sourceIndex = sourceIds.indexOf(blockId);
  if (sourceIndex < 0) {
    return null;
  }

  const sameList = source.parentId === destParentId && source.columnIndex === destColumnIndex;
  if (sameList && (destIndex === sourceIndex || destIndex === sourceIndex + 1)) {
    return null;
  }

  if (sameList) {
    sourceIds.splice(sourceIndex, 1);
    const insertAt = destIndex > sourceIndex ? destIndex - 1 : destIndex;
    sourceIds.splice(Math.max(0, Math.min(insertAt, sourceIds.length)), 0, blockId);
    emailbuilderWriteList(next[source.parentId], source.columnIndex, sourceIds);
  } else {
    sourceIds.splice(sourceIndex, 1);
    emailbuilderWriteList(next[source.parentId], source.columnIndex, sourceIds);
    const destIds = emailbuilderReadList(next[destParentId], destColumnIndex).slice();
    destIds.splice(Math.max(0, Math.min(destIndex, destIds.length)), 0, blockId);
    emailbuilderWriteList(next[destParentId], destColumnIndex, destIds);
  }

  return next;
}


function emailbuilderMoveBlock(blockId, destParentId, destColumnIndex, destIndex) {
  const document = emailbuilderReadDocument();
  const next = emailbuilderDocumentMoveBlock(document, blockId, destParentId, destColumnIndex, destIndex);
  if (!next) {
    return false;
  }
  Fg(next);
  Nu(blockId);
  return true;
}


function emailbuilderInsertAfterId(ids, sourceId, newId) {
  if (!ids) {
    return ids;
  }
  const index = ids.indexOf(sourceId);
  if (index < 0) {
    return ids;
  }
  const next = ids.slice();
  next.splice(index + 1, 0, newId);
  return next;
}


/**
 * Deep-clone a block and every nested child, assigning new IDs so the
 * duplicate can sit next to the original without sharing document keys.
 */
function emailbuilderCloneBlockTree(sourceId, document) {
  const clonedBlocks = {};

  function cloneOne(id) {
    const original = document[id];
    if (!original) {
      return null;
    }

    const newId = emailbuilderNewBlockId();
    const cloned = JSON.parse(JSON.stringify(original));

    if (cloned.data && cloned.data.props && Array.isArray(cloned.data.props.childrenIds)) {
      cloned.data.props.childrenIds = cloned.data.props.childrenIds.map(cloneOne).filter(Boolean);
    }

    if (cloned.data && cloned.data.props && Array.isArray(cloned.data.props.columns)) {
      cloned.data.props.columns = cloned.data.props.columns.map(function (column) {
        return Object.assign({}, column, {
          childrenIds: (column.childrenIds || []).map(cloneOne).filter(Boolean)
        });
      });
    }

    if (cloned.type === "EmailLayout" && cloned.data && Array.isArray(cloned.data.childrenIds)) {
      cloned.data.childrenIds = cloned.data.childrenIds.map(cloneOne).filter(Boolean);
    }

    clonedBlocks[newId] = cloned;
    return newId;
  }

  return {
    newRootId: cloneOne(sourceId),
    clonedBlocks: clonedBlocks
  };
}


function emailbuilderDuplicateBlock(blockId, document) {
  if (!blockId || !document || !document[blockId]) {
    return;
  }

  const cloned = emailbuilderCloneBlockTree(blockId, document);
  if (!cloned.newRootId) {
    return;
  }

  const newDocument = Object.assign({}, document, cloned.clonedBlocks);

  Object.keys(newDocument).forEach(function (id) {
    if (cloned.clonedBlocks[id]) {
      return;
    }

    const block = newDocument[id];
    if (block.type === "EmailLayout" && block.data.childrenIds && block.data.childrenIds.indexOf(blockId) !== -1) {
      newDocument[id] = Object.assign({}, block, {
        data: Object.assign({}, block.data, {
          childrenIds: emailbuilderInsertAfterId(block.data.childrenIds, blockId, cloned.newRootId)
        })
      });
      return;
    }

    if (block.type === "Container" && block.data.props && block.data.props.childrenIds && block.data.props.childrenIds.indexOf(blockId) !== -1) {
      newDocument[id] = Object.assign({}, block, {
        data: Object.assign({}, block.data, {
          props: Object.assign({}, block.data.props, {
            childrenIds: emailbuilderInsertAfterId(block.data.props.childrenIds, blockId, cloned.newRootId)
          })
        })
      });
      return;
    }

    if (block.type === "ColumnsContainer" && block.data.props && Array.isArray(block.data.props.columns)) {
      const columns = block.data.props.columns;
      const containsBlock = columns.some(function (column) {
        return column.childrenIds && column.childrenIds.indexOf(blockId) !== -1;
      });
      if (!containsBlock) {
        return;
      }
      newDocument[id] = {
        type: "ColumnsContainer",
        data: {
          style: block.data.style,
          props: Object.assign({}, block.data.props, {
            columns: columns.map(function (column) {
              return {
                childrenIds: emailbuilderInsertAfterId(column.childrenIds, blockId, cloned.newRootId) || column.childrenIds
              };
            })
          })
        }
      };
    }
  });

  Fg(newDocument);
  Nu(cloned.newRootId);
}


function emailbuilderDuplicateIcon() {
  return R.createElement("svg", {
    className: "MuiSvgIcon-root MuiSvgIcon-fontSizeSmall",
    focusable: "false",
    "aria-hidden": "true",
    viewBox: "0 0 24 24",
    style: { width: 20, height: 20, fontSize: "1.25rem" }
  }, R.createElement("path", { d: emailbuilderDuplicateIconPath }));
}


/**
 * Replace EmailBuilder's TuneMenu (move/delete) with the same actions plus
 * duplicate. These minified names (Rpe, Sa, Fg, Nu, Xl, ...) come from the
 * bundled email-builder.js and are already used by the save/load helpers.
 */
function emailbuilderAddonPatchTuneMenu() {
  if (typeof Rpe !== "function") {
    console.warn("EmailBuilder TuneMenu is not available to patch");
    return;
  }
  if (Rpe.__nimletterPatched) {
    return;
  }

  Rpe = function TuneMenuWithDuplicate({ blockId: e }) {
    const t = Sa();
    const n = () => {
      var i, a, o;
      const l = d => d && d.filter(m => m !== e);
      const c = Object.assign({}, t);
      for (const [d, m] of Object.entries(c)) {
        const h = m;
        if (d !== e) switch (h.type) {
          case "EmailLayout":
            c[d] = Object.assign(Object.assign({}, h), {
              data: Object.assign(Object.assign({}, h.data), {
                childrenIds: l(h.data.childrenIds)
              })
            });
            break;
          case "Container":
            c[d] = Object.assign(Object.assign({}, h), {
              data: Object.assign(Object.assign({}, h.data), {
                props: Object.assign(Object.assign({}, h.data.props), {
                  childrenIds: l((i = h.data.props) === null || i === void 0 ? void 0 : i.childrenIds)
                })
              })
            });
            break;
          case "ColumnsContainer":
            c[d] = {
              type: "ColumnsContainer",
              data: {
                style: h.data.style,
                props: Object.assign(Object.assign({}, h.data.props), {
                  columns: (o = (a = h.data.props) === null || a === void 0 ? void 0 : a.columns) === null || o === void 0 ? void 0 : o.map(g => ({
                    childrenIds: l(g.childrenIds)
                  }))
                })
              }
            };
            break;
          default:
            c[d] = h;
        }
      }
      delete c[e];
      Fg(c);
    };
    const r = i => {
      var a, o, l;
      const c = m => {
        if (!m) return m;
        const h = m.indexOf(e);
        if (h < 0) return m;
        const g = [...m];
        return i === "up" && h > 0 ? [g[h], g[h - 1]] = [g[h - 1], g[h]] : i === "down" && h < g.length - 1 && ([g[h], g[h + 1]] = [g[h + 1], g[h]]), g;
      };
      const d = Object.assign({}, t);
      for (const [m, h] of Object.entries(d)) {
        const g = h;
        if (m !== e) switch (g.type) {
          case "EmailLayout":
            d[m] = Object.assign(Object.assign({}, g), {
              data: Object.assign(Object.assign({}, g.data), {
                childrenIds: c(g.data.childrenIds)
              })
            });
            break;
          case "Container":
            d[m] = Object.assign(Object.assign({}, g), {
              data: Object.assign(Object.assign({}, g.data), {
                props: Object.assign(Object.assign({}, g.data.props), {
                  childrenIds: c((a = g.data.props) === null || a === void 0 ? void 0 : a.childrenIds)
                })
              })
            });
            break;
          case "ColumnsContainer":
            d[m] = {
              type: "ColumnsContainer",
              data: {
                style: g.data.style,
                props: Object.assign(Object.assign({}, g.data.props), {
                  columns: (l = (o = g.data.props) === null || o === void 0 ? void 0 : o.columns) === null || l === void 0 ? void 0 : l.map(E => ({
                    childrenIds: c(E.childrenIds)
                  }))
                })
              }
            };
            break;
          default:
            d[m] = g;
        }
      }
      Fg(d);
      Nu(e);
    };
    const duplicate = () => emailbuilderDuplicateBlock(e, t);
    const iconSx = { color: "text.primary" };

    return R.createElement(Xl, { sx: Npe, onClick: i => i.stopPropagation() },
      R.createElement(dn, null,
        R.createElement(Di, { title: "Move up", placement: "left-start" },
          R.createElement(ua, { onClick: () => r("up"), sx: iconSx, "aria-label": "Move up" },
            R.createElement(rae, { fontSize: "small" }))),
        R.createElement(Di, { title: "Move down", placement: "left-start" },
          R.createElement(ua, { onClick: () => r("down"), sx: iconSx, "aria-label": "Move down" },
            R.createElement(nae, { fontSize: "small" }))),
        R.createElement(Di, { title: "Duplicate", placement: "left-start" },
          R.createElement(ua, { onClick: duplicate, sx: iconSx, "aria-label": "Duplicate" },
            emailbuilderDuplicateIcon())),
        R.createElement(Di, { title: "Delete", placement: "left-start" },
          R.createElement(ua, { onClick: n, sx: iconSx, "aria-label": "Delete" },
            R.createElement(cae, { fontSize: "small" })))
      )
    );
  };

  Rpe.__nimletterPatched = true;
}


function emailbuilderAddonInjectCloneButton() {
  const moveUpButtons = document.querySelectorAll('[aria-label="Move up"]');
  moveUpButtons.forEach(function (moveUp) {
    const stack = moveUp.closest(".MuiStack-root");
    if (!stack || stack.querySelector('[aria-label="Duplicate"]')) {
      return;
    }
    const deleteBtn = stack.querySelector('[aria-label="Delete"]');
    if (!deleteBtn) {
      return;
    }

    const cloneBtn = deleteBtn.cloneNode(true);
    cloneBtn.setAttribute("aria-label", "Duplicate");
    cloneBtn.setAttribute("title", "Duplicate");
    const path = cloneBtn.querySelector("path");
    if (path) {
      path.setAttribute("d", emailbuilderDuplicateIconPath);
    }
    const testId = cloneBtn.querySelector("[data-testid]");
    if (testId) {
      testId.setAttribute("data-testid", "ContentCopyOutlinedIcon");
    }
    cloneBtn.addEventListener("click", function (event) {
      event.preventDefault();
      event.stopPropagation();
      const doc = emailbuilderReadDocument();
      const selectedId = (typeof Fn !== "undefined" && Fn.getState) ? Fn.getState().selectedBlockId : null;
      if (selectedId && doc) {
        emailbuilderDuplicateBlock(selectedId, doc);
      }
    });
    deleteBtn.parentNode.insertBefore(cloneBtn, deleteBtn);
  });
}


function emailbuilderAddonWatchUi() {
  if (window.emailbuilderAddonObserver) {
    return;
  }
  const root = document.getElementById("root") || document.body;
  window.emailbuilderAddonObserver = new MutationObserver(function () {
    emailbuilderAddonInjectCloneButton();
    emailbuilderAddonSyncMobilePreview();
  });
  window.emailbuilderAddonObserver.observe(root, { childList: true, subtree: true });
  emailbuilderAddonInjectCloneButton();
  emailbuilderAddonSyncMobilePreview();
  emailbuilderAddonEnsureTree();
}


function emailbuilderHasMobileOuter(props) {
  return !!(props && props.mobileOuter);
}


function emailbuilderRestoreMobileOuter(parsed, source) {
  parsed.props = Object.assign({}, parsed.props, {
    mobileOuter: emailbuilderHasMobileOuter(source && source.props)
  });
  return parsed;
}


function emailbuilderMobileOuterClass(props) {
  return emailbuilderHasMobileOuter(props) ? "nl-mobile-outer" : undefined;
}


function emailbuilderAddonEnsureMobileOuterStyles() {
  if (document.getElementById("nl-mobile-outer-style")) {
    return;
  }
  const style = document.createElement("style");
  style.id = "nl-mobile-outer-style";
  style.textContent = emailbuilderMobileOuterCss;
  document.head.appendChild(style);
}


function emailbuilderAddonSyncMobilePreview() {
  if (typeof Fn === "undefined" || typeof Fn.getState !== "function") {
    return;
  }

  const apply = function () {
    const root = document.getElementById("root");
    if (!root) {
      return;
    }
    root.classList.toggle("nl-mobile-preview", Fn.getState().selectedScreenSize === "mobile");
  };

  apply();
  if (!Fn.__nimletterMobileUnsub && typeof Fn.subscribe === "function") {
    Fn.__nimletterMobileUnsub = Fn.subscribe(apply);
  }
}


/**
 * Mark specific Container blocks as the mobile outer layer. EmailBuilder has
 * no responsive padding, so we keep a flag on props, render class
 * nl-mobile-outer, and override left/right padding in CSS.
 */
function emailbuilderAddonPatchMobileOuter() {
  if (typeof d4 === "function" && !d4.__nimletterPatched) {
    const originalD4 = d4;
    d4 = function (props) {
      const element = originalD4(props);
      if (!props || !props.className) {
        return element;
      }
      return R.cloneElement(element, {
        className: [element.props.className, props.className].filter(Boolean).join(" ").trim()
      });
    };
    d4.__nimletterPatched = true;
  }

  if (typeof q6 !== "undefined" && q6.Container && !q6.Container.Component.__nimletterPatched) {
    const originalApe = q6.Container.Component;
    q6.Container.Component = function (props) {
      const element = originalApe(props);
      const className = emailbuilderMobileOuterClass(props && props.props);
      return className ? R.cloneElement(element, { className: className }) : element;
    };
    q6.Container.Component.__nimletterPatched = true;
  }

  if (typeof Dpe === "function" && !Dpe.__nimletterPatched) {
    Dpe = function ContainerWithMobileOuter({ style: e, props: t }) {
      var n;
      const r = (n = t == null ? void 0 : t.childrenIds) !== null && n !== void 0 ? n : [];
      const i = Sa();
      const a = GE();
      return R.createElement(d4, {
        style: e,
        className: emailbuilderMobileOuterClass(t)
      }, R.createElement(yp, {
        childrenIds: r,
        onChange: ({
          block: o,
          blockId: l,
          childrenIds: c
        }) => {
          const current = i[a];
          Wm({
            [l]: o,
            [a]: {
              type: "Container",
              data: Object.assign({}, current.data, {
                props: Object.assign({}, current.data.props, {
                  childrenIds: c
                })
              })
            }
          });
          Nu(l);
        }
      }));
    };
    Dpe.__nimletterPatched = true;
  }

  if (typeof kse === "function" && !kse.__nimletterPatched) {
    kse = function ContainerInspectorWithMobileOuter({ data: e, setData: t }) {
      const [, n] = O.useState(null);
      const r = i => {
        const a = p4.safeParse(i);
        if (a.success) {
          t(emailbuilderRestoreMobileOuter(a.data, i));
          n(null);
        } else {
          n(a.error);
        }
      };
      const checked = emailbuilderHasMobileOuter(e.props);

      return R.createElement(ya, {
        title: "Container block"
      }, R.createElement(Mo, {
        names: ["backgroundColor", "borderColor", "borderRadius", "padding"],
        value: e.style,
        onChange: i => r(Object.assign(Object.assign({}, e), {
          style: i
        }))
      }), R.createElement("label", {
        className: "nl-mobile-outer-toggle"
      }, R.createElement("input", {
        type: "checkbox",
        checked: checked,
        onChange: i => r(Object.assign(Object.assign({}, e), {
          props: Object.assign(Object.assign({}, e.props), {
            mobileOuter: i.target.checked
          })
        }))
      }), "Reduce side padding on mobile"), R.createElement("div", {
        className: "nl-mobile-outer-help"
      }, "On phones this container’s left and right padding becomes " + emailbuilderMobileOuterPaddingPx + "px. Nested blocks keep their own padding. Use this on the outer layer you want as the mobile gutter."));
    };
    kse.__nimletterPatched = true;
  }
}


let emailbuilderTreeCollapsed = {};
let emailbuilderTreeDragId = null;


function emailbuilderTreePreview(block) {
  const props = block && block.data && block.data.props;
  if (!props) {
    return "";
  }
  const raw = typeof props.text === "string" ? props.text : (typeof props.alt === "string" ? props.alt : "");
  return raw.replace(/\s+/g, " ").trim().slice(0, 28);
}


function emailbuilderTreeNodes(document) {
  const nodes = [];
  if (!document || !document.root) {
    return nodes;
  }

  function pushBlock(id, parentId, parentSlot, depth) {
    const block = document[id];
    if (!block) {
      return;
    }
    const columns = block.type === "ColumnsContainer" && block.data && block.data.props
      ? (block.data.props.columns || [])
      : null;
    const childIds = columns ? [] : emailbuilderReadList(block, null);
    const expandable = !!(columns && columns.length) || childIds.length > 0;
    const collapsed = !!emailbuilderTreeCollapsed[id];
    const preview = emailbuilderTreePreview(block);

    nodes.push({
      kind: "block",
      id: id,
      rowKey: "block:" + id,
      type: block.type,
      label: block.type,
      preview: preview,
      parentId: parentId,
      parentSlot: parentSlot,
      depth: depth,
      expandable: expandable,
      collapsed: collapsed,
      movable: id !== "root"
    });

    if (collapsed) {
      return;
    }

    if (columns) {
      columns.forEach(function (column, slotIndex) {
        const slotKey = id + ":slot:" + slotIndex;
        const slotCollapsed = !!emailbuilderTreeCollapsed[slotKey];
        nodes.push({
          kind: "slot",
          id: id,
          slotIndex: slotIndex,
          rowKey: "slot:" + slotKey,
          type: "Slot",
          label: "Slot-" + slotIndex,
          preview: "",
          parentId: id,
          parentSlot: slotIndex,
          depth: depth + 1,
          expandable: (column.childrenIds || []).length > 0,
          collapsed: slotCollapsed,
          movable: false
        });
        if (!slotCollapsed) {
          (column.childrenIds || []).forEach(function (childId) {
            pushBlock(childId, id, slotIndex, depth + 2);
          });
        }
      });
      return;
    }

    childIds.forEach(function (childId) {
      pushBlock(childId, id, null, depth + 1);
    });
  }

  pushBlock("root", null, null, 0);
  return nodes;
}


function emailbuilderTreeClearDrop() {
  const panel = document.getElementById("emailbuilderTree");
  if (!panel) {
    return;
  }
  panel.querySelectorAll(".drop-before, .drop-after, .drop-inside, .is-dragging").forEach(function (row) {
    row.classList.remove("drop-before", "drop-after", "drop-inside", "is-dragging");
  });
}


function emailbuilderTreeCanDropInside(row) {
  if (!row) {
    return false;
  }
  if (row.dataset.kind === "slot") {
    return true;
  }
  return row.dataset.type === "EmailLayout" || row.dataset.type === "Container";
}


function emailbuilderTreeDropWhere(row, clientY) {
  if (!row) {
    return null;
  }
  if (row.dataset.id === "root") {
    return "inside";
  }
  const canInside = emailbuilderTreeCanDropInside(row);
  const rect = row.getBoundingClientRect();
  const y = clientY - rect.top;
  const height = rect.height || 1;
  if (row.dataset.kind === "slot") {
    if (y < height * 0.35) {
      return "before";
    }
    if (y > height * 0.65) {
      return "after";
    }
    return "inside";
  }
  if (canInside) {
    if (y < height * 0.28) {
      return "before";
    }
    if (y > height * 0.72) {
      return "after";
    }
    return "inside";
  }
  return y < height * 0.5 ? "before" : "after";
}


function emailbuilderTreeDest(row, where, document) {
  if (!row || !where || !document) {
    return null;
  }
  const kind = row.dataset.kind;
  const id = row.dataset.id;
  const slotIndex = emailbuilderParseSlotIndex(row.dataset.slotIndex);
  const parentId = row.dataset.parentId || null;
  const parentSlot = emailbuilderParseSlotIndex(row.dataset.parentSlot);

  if (kind === "slot") {
    const list = emailbuilderReadList(document[id], slotIndex);
    if (where === "before") {
      return { parentId: id, columnIndex: slotIndex, index: 0 };
    }
    return { parentId: id, columnIndex: slotIndex, index: list.length };
  }

  if (id === "root" || where === "inside") {
    if (!emailbuilderCanHaveChildren(document[id])) {
      return null;
    }
    return {
      parentId: id,
      columnIndex: null,
      index: emailbuilderReadList(document[id], null).length
    };
  }

  if (!parentId || !document[parentId]) {
    return null;
  }
  const list = emailbuilderReadList(document[parentId], parentSlot);
  const index = list.indexOf(id);
  if (index < 0) {
    return null;
  }
  return {
    parentId: parentId,
    columnIndex: parentSlot,
    index: where === "before" ? index : index + 1
  };
}


function emailbuilderTreeBind(panel) {
  if (panel.__nimletterTreeBound) {
    return;
  }
  panel.__nimletterTreeBound = true;

  panel.addEventListener("click", function (event) {
    const chevron = event.target.closest(".nl-eb-tree-chevron");
    if (chevron) {
      event.preventDefault();
      event.stopPropagation();
      const row = chevron.closest(".nl-eb-tree-row");
      if (!row) {
        return;
      }
      const key = row.dataset.collapseKey;
      if (!key) {
        return;
      }
      emailbuilderTreeCollapsed[key] = !emailbuilderTreeCollapsed[key];
      emailbuilderTreeRender();
      return;
    }

    const row = event.target.closest(".nl-eb-tree-row");
    if (!row || row.dataset.kind !== "block") {
      return;
    }
    event.preventDefault();
    event.stopPropagation();
    if (typeof Nu === "function") {
      Nu(row.dataset.id);
    }
  });

  panel.addEventListener("dragstart", function (event) {
    const grip = event.target.closest(".nl-eb-tree-grip");
    const row = event.target.closest(".nl-eb-tree-row");
    if (!grip || !row || row.dataset.movable !== "true") {
      event.preventDefault();
      return;
    }
    emailbuilderTreeDragId = row.dataset.id;
    event.dataTransfer.effectAllowed = "move";
    event.dataTransfer.setData("text/plain", row.dataset.id);
    row.classList.add("is-dragging");
  });

  panel.addEventListener("dragend", function () {
    emailbuilderTreeDragId = null;
    emailbuilderTreeClearDrop();
  });

  panel.addEventListener("dragover", function (event) {
    event.preventDefault();
    const row = event.target.closest(".nl-eb-tree-row");
    if (!row || !emailbuilderTreeDragId) {
      return;
    }
    event.dataTransfer.dropEffect = "move";
    const where = emailbuilderTreeDropWhere(row, event.clientY);
    emailbuilderTreeClearDrop();
    const dragRow = panel.querySelector('.nl-eb-tree-row[data-id="' + emailbuilderTreeDragId + '"][data-kind="block"]');
    if (dragRow) {
      dragRow.classList.add("is-dragging");
    }
    if (where) {
      row.classList.add("drop-" + where);
    }
  });

  panel.addEventListener("drop", function (event) {
    const row = event.target.closest(".nl-eb-tree-row");
    const blockId = emailbuilderTreeDragId || event.dataTransfer.getData("text/plain");
    emailbuilderTreeDragId = null;
    emailbuilderTreeClearDrop();
    if (!row || !blockId) {
      return;
    }
    event.preventDefault();
    event.stopPropagation();
    const document = emailbuilderReadDocument();
    const dest = emailbuilderTreeDest(row, emailbuilderTreeDropWhere(row, event.clientY), document);
    if (!dest) {
      return;
    }
    emailbuilderMoveBlock(blockId, dest.parentId, dest.columnIndex, dest.index);
  });
}


function emailbuilderTreeRender() {
  const list = document.getElementById("emailbuilderTreeList");
  if (!list) {
    return;
  }

  const documentData = emailbuilderReadDocument();
  const selectedId = (typeof Fn !== "undefined" && Fn.getState) ? Fn.getState().selectedBlockId : null;
  const nodes = emailbuilderTreeNodes(documentData);

  list.innerHTML = "";
  if (!nodes.length) {
    const empty = document.createElement("div");
    empty.className = "nl-eb-tree-empty";
    empty.textContent = "No blocks yet";
    list.appendChild(empty);
    return;
  }

  nodes.forEach(function (node) {
    const row = document.createElement("div");
    row.className = "nl-eb-tree-row";
    if (node.kind === "slot") {
      row.classList.add("is-slot");
    }
    if (node.kind === "block" && node.id === selectedId) {
      row.classList.add("is-selected");
    }
    row.style.paddingLeft = (6 + node.depth * 14) + "px";
    row.dataset.kind = node.kind;
    row.dataset.id = node.id;
    row.dataset.type = node.type;
    row.dataset.slotIndex = node.kind === "slot" ? String(node.slotIndex) : "";
    row.dataset.parentId = node.parentId || "";
    row.dataset.parentSlot = node.parentSlot === null || node.parentSlot === undefined ? "none" : String(node.parentSlot);
    row.dataset.movable = node.movable ? "true" : "false";
    row.dataset.collapseKey = node.kind === "slot" ? (node.id + ":slot:" + node.slotIndex) : node.id;
    row.title = node.label;

    const chevron = document.createElement("button");
    chevron.type = "button";
    chevron.className = "nl-eb-tree-chevron";
    chevron.tabIndex = -1;
    if (!node.expandable) {
      chevron.classList.add("is-empty");
    } else if (!node.collapsed) {
      chevron.classList.add("is-open");
    }
    chevron.setAttribute("aria-label", node.collapsed ? "Expand" : "Collapse");
    row.appendChild(chevron);

    const label = document.createElement("span");
    label.className = "nl-eb-tree-label";
    label.textContent = node.label;
    row.appendChild(label);

    if (node.preview) {
      const preview = document.createElement("span");
      preview.className = "nl-eb-tree-preview";
      preview.textContent = node.preview;
      row.appendChild(preview);
    }

    if (node.movable) {
      const grip = document.createElement("span");
      grip.className = "nl-eb-tree-grip";
      grip.draggable = true;
      grip.title = "Drag to move";
      row.appendChild(grip);
    }

    list.appendChild(row);
  });
}


function emailbuilderTreeMount() {
  const rootArea = document.getElementById("rootArea");
  const root = document.getElementById("root");
  if (!rootArea || !root) {
    return null;
  }

  let panel = document.getElementById("emailbuilderTree");
  if (!panel) {
    panel = document.createElement("aside");
    panel.id = "emailbuilderTree";
    panel.className = "nl-eb-tree";
    panel.setAttribute("aria-label", "Email block tree");

    const header = document.createElement("div");
    header.className = "nl-eb-tree-header";
    const title = document.createElement("div");
    title.className = "nl-eb-tree-title";
    title.textContent = "Blocks";
    const hint = document.createElement("div");
    hint.className = "nl-eb-tree-hint";
    hint.textContent = "Drag to move. Click to select.";
    header.appendChild(title);
    header.appendChild(hint);

    const list = document.createElement("div");
    list.id = "emailbuilderTreeList";
    list.className = "nl-eb-tree-list";

    panel.appendChild(header);
    panel.appendChild(list);
    rootArea.insertBefore(panel, root);
  }

  emailbuilderTreeBind(panel);
  return panel;
}


function emailbuilderAddonEnsureTree() {
  if (!emailbuilderTreeMount()) {
    return;
  }
  emailbuilderTreeRender();
  if (typeof Fn !== "undefined" && typeof Fn.subscribe === "function" && !Fn.__nimletterTreeUnsub) {
    Fn.__nimletterTreeUnsub = Fn.subscribe(function () {
      emailbuilderTreeRender();
    });
  }
}


/**
 * Close EmailBuilder's sample-template drawer. It opens by default and sits
 * over the Blocks tree. The toolbar FirstPage/LastPage button still toggles it.
 */
function emailbuilderAddonHideSamplesDrawer() {
  if (typeof Fn === "undefined" || typeof Fn.setState !== "function") {
    return;
  }
  if (Fn.getState().samplesDrawerOpen) {
    Fn.setState({ samplesDrawerOpen: false });
  }
}


/*
let jsonStructure = JSON.parse(emailbuilderAddonGetJson());
let html = fpe(jsonStructure, { rootBlockId: 'root' });
let rawHtml = html.replace(/&quot;/g, '"');

console.log(rawHtml); // Outputs raw HTML with real quotes

// Return formatted HTML for preview in a PRE
_1e(emailbuilderAddonGetJson())
.then(r => {
    console.log(r)
})

// Return JSON but formatted like &quot;
g1e(emailbuilderAddonGetJson())
.then(r => {
    console.log(r)
})

*/
