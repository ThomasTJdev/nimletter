


let
  globalMailData,
  globalMailEditorType,
  globalMailEditorHTML,
  globalMailEditorContent;


function addMail() {

  const html = jsCreateElement('div', {
    attrs: {
      style: "width: 300px;"
    },
    children: [
      jsCreateElement('div', {
        attrs: {
          class: 'headingH3 mb20 center'
        },
        children: ['Add mail']
      }),
      jsCreateElement('div', {
        attrs: {
          class: 'itemBlock mb20'
        },
        children: [
          jsCreateElement('label', {
            attrs: {
              class: 'forinput'
            },
            children: ['Mail name']
          }),
          jsCreateElement('input', {
            attrs: {
              type: 'text',
              id: 'mailNewName'
            }
          })
        ]
      }),
      jsCreateElement('div', {
        attrs: {
          class: 'itemBlock mb20'
        },
        children: [
          jsCreateElement('label', {
            attrs: {
              class: 'forinput'
            },
            children: ['Tags (comma separated)']
          }),
          jsCreateElement('input', {
            attrs: {
              type: 'text',
              id: 'mailNewTags'
            }
          })
        ]
      }),
      jsCreateElement('div', {
        attrs: {
          class: 'itemBlock mb20'
        },
        children: [
          jsCreateElement('label', {
            attrs: {
              class: 'inborder'
            },
            children: ['Category']
          }),
          jsCreateElement('select', {
            attrs: {
              type: 'text',
              id: 'mailNewCategory'
            },
            children: [
              jsCreateElement('option', {
                attrs: {
                  value: 'template'
                },
                children: ['Template']
              }),
              jsCreateElement('option', {
                attrs: {
                  value: 'newsletter'
                },
                children: ['Newsletter']
              }),
              jsCreateElement('option', {
                attrs: {
                  value: 'drip'
                },
                children: ['drip']
              }),
              jsCreateElement('option', {
                attrs: {
                  value: 'campaign'
                },
                children: ['Campaign']
              }),
              jsCreateElement('option', {
                attrs: {
                  value: 'singleshot'
                },
                children: ['Single shot']
              })
            ]
          })
        ]
      }),
      jsCreateElement('div', {
        attrs: {
          style: "font-size: 12px;margin:20px;"
        },
        children: [
          'A mail is a message that you can send to a list of contacts. It can be used in a flow or directly from a list.'
        ]
      }),
      jsCreateElement('div', {
        children: [
          jsCreateElement('button', {
            attrs: {
              class: 'buttonIcon',
              onclick: 'addMailDo()'
            },
            rawHtml: [
              '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="size-6"><path stroke-linecap="round" stroke-linejoin="round" d="M12 9v6m3-3H9m12 0a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" /></svg><div class="ml5">Add mail</div>'
            ]
          })
        ]
      })
    ]
  });
  rawModalLoader(jsRender(html));
  labelFloater();
  setTimeout(() => {
    dqs("#mailNewName").focus();
  }, 100);

}

function addMailDo() {
  let
    name = dqs("#mailNewName").value,
    tags = dqs("#mailNewTags").value,
    category = dqs("#mailNewCategory").value;

  fetch("/api/mails/create", {
    method: "POST",
    body: new URLSearchParams({
      name: name,
      tags: tags,
      category: category
    })
  })
  .then(manageErrors)
  .then(response => response.json())
  .then(data => {
    dqs(".modalpop").remove();
    loadMail(data.id);
  });

}


async function loadMailToVars(id) {
  const data = await fetch("/api/mails/get?mailID=" + id, {
    method: "GET"
  })
  .then(manageErrors)
  .then(response => response.json())
  .then(data => {
    globalMailEditorContent = data.contentEditor;
    emailbuilderShow('setJSON');
  });
}


async function loadMail(id) {
  fetch("/api/mails/get?mailID=" + id, {
    method: "GET"
  })
  .then(manageErrors)
  .then(response => response.json())
  .then(data => {
    globalMailData = data;
    globalMailEditorType = data.editorType;

    const html = jsCreateElement('div', {
      attrs: {
        style: "max-width: 800px;"
      },
      children: [
        jsCreateElement('div', {
          attrs: {
            class: 'mb50'
          },
          children: [
            jsCreateElement('div', {
              attrs: {
                style: 'display: flex;align-items: center;justify-content: space-between;'
              },
              children: [
                jsCreateElement('button', {
                  attrs: {
                    class: 'mailSave',
                    onclick: 'saveMail(' + id + ')'
                  },
                  rawHtml: [
                    '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="size-6" style="height: 22px;width: 22px;"><path stroke-linecap="round" stroke-linejoin="round" d="m20.25 7.5-.625 10.632a2.25 2.25 0 0 1-2.247 2.118H6.622a2.25 2.25 0 0 1-2.247-2.118L3.75 7.5m8.25 3v6.75m0 0-3-3m3 3 3-3M3.375 7.5h17.25c.621 0 1.125-.504 1.125-1.125v-1.5c0-.621-.504-1.125-1.125-1.125H3.375c-.621 0-1.125.504-1.125 1.125v1.5c0 .621.504 1.125 1.125 1.125Z"></path></svg><div class="ml5">Save changes</div>'
                  ]
                }),
                jsCreateElement('div', {
                  attrs: {
                    style: 'display: flex;align-items: center;gap: 10px;'
                  },
                  children: [
                    jsCreateElement('button', {
                      attrs: {
                        class: 'mailSend buttonIcon',
                        style: 'width: fit-content;',
                        onclick: 'duplicateMail(' + id + ')',
                      },
                      rawHtml: [
                        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" width="24" height="24" stroke-width="2"><path d="M7 7m0 2.667a2.667 2.667 0 0 1 2.667 -2.667h8.666a2.667 2.667 0 0 1 2.667 2.667v8.666a2.667 2.667 0 0 1 -2.667 2.667h-8.666a2.667 2.667 0 0 1 -2.667 -2.667z"></path><path d="M4.012 16.737a2.005 2.005 0 0 1 -1.012 -1.737v-10c0 -1.1 .9 -2 2 -2h10c.75 0 1.158 .385 1.5 1"></path></svg><div class="ml5">Duplicate</div>'
                      ]
                    }),
                    jsCreateElement('button', {
                      attrs: {
                        class: 'mailSend buttonIcon',
                        style: 'width: fit-content;',
                        onclick: 'sendMail(' + id + ')'
                      },
                      rawHtml: [
                        '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="size-6"><path stroke-linecap="round" stroke-linejoin="round" d="M21.75 6.75v10.5a2.25 2.25 0 0 1-2.25 2.25h-15a2.25 2.25 0 0 1-2.25-2.25V6.75m19.5 0A2.25 2.25 0 0 0 19.5 4.5h-15a2.25 2.25 0 0 0-2.25 2.25m19.5 0v.243a2.25 2.25 0 0 1-1.07 1.916l-7.5 4.615a2.25 2.25 0 0 1-2.36 0L3.32 8.91a2.25 2.25 0 0 1-1.07-1.916V6.75" /></svg><div class="ml5">Send email</div>'
                      ]
                    })
                  ]
                })
              ]
            })
          ]
        }),
        jsCreateElement('div', {
          attrs: {
            class: 'mb30',
            style: 'display: grid ; grid-template-columns: 1fr 1fr; grid-gap: 30px;'
          },
          children: [
            jsCreateElement('div', {
              attrs: {
                class: 'itemBlock'
              },
              children: [
                jsCreateElement('label', {
                  attrs: {
                    class: 'forinput'
                  },
                  children: ['Mail name']
                }),
                jsCreateElement('input', {
                  attrs: {
                    type: 'text',
                    id: 'mailEditName',
                    value: data.name
                  }
                })
              ]
            }),
            jsCreateElement('div', {
              attrs: {
                class: 'itemBlock'
              },
              children: [
                jsCreateElement('label', {
                  attrs: {
                    class: 'forinput'
                  },
                  children: ['Mail event identifier']
                }),
                jsCreateElement('input', {
                  attrs: {
                    type: 'text',
                    id: 'mailEditIdentifier',
                    value: data.identifier,
                  }
                })
              ]
            }),
          ]
        }),
        jsCreateElement('div', {
          attrs: {
            class: 'mb30',
            style: 'display: grid ; grid-template-columns: 1fr 1fr; grid-gap: 30px;'
          },
          children: [
            jsCreateElement('div', {
              attrs: {
                class: 'itemBlock'
              },
              children: [
                jsCreateElement('label', {
                  attrs: {
                    class: 'forinput'
                  },
                  children: ['Subject']
                }),
                jsCreateElement('input', {
                  attrs: {
                    type: 'text',
                    id: 'mailEditSubject',
                    value: data.subject
                  }
                })
              ]
            }),
            jsCreateElement('div', {
              attrs: {
                class: 'itemBlock'
              },
              children: [
                jsCreateElement('label', {
                  attrs: {
                    class: 'inborder'
                  },
                  children: ['Category']
                }),
                jsCreateElement('select', {
                  attrs: {
                    type: 'text',
                    id: 'mailEditCategory'
                  },
                  children: [
                    jsCreateElement('option', {
                      attrs: {
                        value: 'template',
                        selected: data.category == 'template' ? 'selected' : false
                      },
                      children: ['Template']
                    }),
                    jsCreateElement('option', {
                      attrs: {
                        value: 'newsletter',
                        selected: data.category == 'newsletter' ? 'selected' : false
                      },
                      children: ['Newsletter']
                    }),
                    jsCreateElement('option', {
                      attrs: {
                        value: 'drip',
                        selected: data.category == 'drip' ? 'selected' : false
                      },
                      children: ['Drip']
                    }),
                    jsCreateElement('option', {
                      attrs: {
                        value: 'campaign',
                        selected: data.category == 'campaign' ? 'selected' : false
                      },
                      children: ['Campaign']
                    }),
                    jsCreateElement('option', {
                      attrs: {
                        value: 'singleshot',
                        selected: data.category == 'singleshot' ? 'selected' : false
                      },
                      children: ['Single shot']
                    }),
                    jsCreateElement('option', {
                      attrs: {
                        value: 'event',
                        selected: data.category == 'event' ? 'selected' : false
                      },
                      children: ['Event']
                    }),
                    jsCreateElement('option', {
                      attrs: {
                        value: 'archived',
                        selected: data.category == 'archived' ? 'selected' : false
                      },
                      children: ['Archived']
                    })
                  ]
                })
              ]
            }),
          ]
        }),
        jsCreateElement('div', {
          attrs: {
            class: 'mb30',
            style: 'display: grid ; grid-template-columns: 1fr 1fr; grid-gap: 30px;'
          },
          children: [
            jsCreateElement('div', {
              attrs: {
                class: 'itemBlock'
              },
              children: [
                jsCreateElement('label', {
                  attrs: {
                    class: 'forinput'
                  },
                  children: ['Tags (comma separated)']
                }),
                jsCreateElement('input', {
                  attrs: {
                    type: 'text',
                    id: 'mailEditTags',
                    value: data.tags
                  }
                }),
              ]
            }),
            jsCreateElement('div', {
              attrs: {
                style: 'display: flex;align-items: center;'
              },
              children: [
                jsCreateElement('label', {
                  attrs: {
                    class: 'toggleSwitch compact',
                    style: 'margin-right: 10px;'
                  },
                  children: [
                    jsCreateElement('input', {
                      attrs: {
                        id: 'sendOnce',
                        type: 'checkbox',
                        checked: data.send_once ? 'checked' : false
                      }
                    }),
                    jsCreateElement('span', {
                      attrs: {
                        class: 'toggleSlider compact round'
                      }
                    })
                  ]
                }),
                jsCreateElement('div', {
                  attrs: {
                    style: 'font-size: 14px;'
                  },
                  children: [
                    'Only allow this to be sent once per contact'
                  ]
                }),
              ]
            }),
          ]
        }),
        jsCreateElement('div', {
          attrs: {
            class: 'itemBlock mailEditPreviewBlock mb30',
            style: 'margin-top: 30px;'
          },
          children: [
            jsCreateElement('label', {
              attrs: {
                class: 'forinput'
              },
              children: ['Preview']
            }),
            jsCreateElement('div', {
              attrs: {
                id: 'mailEditPreview'
              }
            })
          ]
        })
      ]
    });
    dqs("#heading").innerText = "Edit mail";
    dqs("#work").innerHTML = "";

    const htmlMail = jsRender(html);
    if (globalMailEditorType == "html") {
      const editor = jsCreateElement('div', {
        children: [
          jsCreateElement('textarea', {
            attrs: {
              id: 'mailEditContent',
              class: 'simulateInput hideme',
              style: 'padding: 30px; min-height: 300px;'
            },
            children: [data.contentHTML]
          }),
          jsCreateElement('div', {
            attrs: {
              id: 'mailEditPreviewHTML',
              class: 'simulateInput',
              style: 'width: calc(100% - 25px);'
            },
            rawHtml: [data.contentHTML]
          })
        ]
      });

      qs(htmlMail, "#mailEditPreview").appendChild(jsRender(editor));

      const editbutton = jsCreateElement('div', {
        attrs: {
          style: 'display: flex;'
        },
        children: [
          jsCreateElement('button', {
            attrs: {
              class: 'buttonIcon',
              onclick: 'mailToggleHTMLEditor()'
            },
            rawHtml: [
              '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="size-6"><path stroke-linecap="round" stroke-linejoin="round" d="M12 9v6m3-3H9m12 0a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" /></svg><div  class="editMailButtonInner" class="ml5">Edit mail in HTML</div>'
            ]
          }),
          jsCreateElement('button', {
            attrs: {
              class: 'buttonIcon ml5',
              style: 'width: fit-content;height:auto;',
              onclick: 'switchEditor()'
            },
            rawHtml: [
              '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="size-6"><path stroke-linecap="round" stroke-linejoin="round" d="M3 7.5 7.5 3m0 0L12 7.5M7.5 3v13.5m13.5 0L16.5 21m0 0L12 16.5m4.5 4.5V7.5" /></svg><div class="ml5">Switch editor</div>'
            ]
          })
        ]
      });

      htmlMail.insertBefore(jsRender(editbutton), qs(htmlMail, ".mailEditPreviewBlock"));
    }
    else if (globalMailEditorType == "emailbuilder") {
      const editor = jsCreateElement('div', {
        children: [
          jsCreateElement('div', {
          attrs: {
            id: 'mailEditPreviewHTML',
            class: 'simulateInput',
            style: 'width: calc(100% - 25px);'
          },
          rawHtml: [data.contentHTML]
          })
        ]
      });

      qs(htmlMail, "#mailEditPreview").appendChild(jsRender(editor));

      const editbutton = jsCreateElement('div', {
        attrs: {
          style: 'display: flex;'
        },
        children: [
          jsCreateElement('button', {
            attrs: {
              class: 'buttonIcon',
              onclick: 'loadMailToVars(' + globalMailData.id + ')'
            },
            rawHtml: [
              '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="size-6"><path stroke-linecap="round" stroke-linejoin="round" d="M12 9v6m3-3H9m12 0a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" /></svg><div class="ml5">Edit mail with EmailBuilder</div>'
            ]
          }),
          jsCreateElement('button', {
            attrs: {
              class: 'buttonIcon ml5',
              style: 'width: fit-content; height:auto;',
              onclick: 'switchEditor()'
            },
            rawHtml: [
              '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="size-6"><path stroke-linecap="round" stroke-linejoin="round" d="M3 7.5 7.5 3m0 0L12 7.5M7.5 3v13.5m13.5 0L16.5 21m0 0L12 16.5m4.5 4.5V7.5" /></svg><div class="ml5">Switch editor</div>'
            ]
          })
        ]
      });

      htmlMail.insertBefore(jsRender(editbutton), qs(htmlMail, ".mailEditPreviewBlock"));
    }
    globalMailEditorHTML    = data.contentHTML;
    globalMailEditorContent = data.contentEditor;

    dqs("#work").appendChild(htmlMail);
    labelFloater();


    // On any changes to input, select, textarea find .mailSave and append active
    document.querySelectorAll("input, select, textarea").forEach(item => {
      item.addEventListener("input", function() {
        dqs(".mailSave").classList.add("active");
      });
    });

    dqs("#mailEditIdentifier").addEventListener("keydown", function(e) {
      if (e.key === " ") {
        e.preventDefault();
      }
    });
  });
}


function emailbuilderClear(defaultJson) {
  emailbuilderAddonSetJson(defaultJson);
}


function emailbuilderLoad(callback) {
  const
    scriptURLAddons = "/assets/js/email-builder-addons.js",
    scriptURL = "/assets/js/email-builder.js";

  if (isScriptInjected()) {
    console.log("Script already injected");
    callback();
  } else {
    loadStylesheetManually("https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/default.min.css");
    loadScriptManually(scriptURLAddons)
    .then(() => {
      loadScriptManually(scriptURL)
      .then(() => {
        emailbuilderAddonSavebtn();
        callback();
      });
    });
  }
}


function emailbuilderShow(purpose) {
  if (dqs("#rootArea")) {
    dqs(".modalpop").classList.add("show");
  } else {
    const html = jsCreateElement('div', {
      attrs: {
        id: "rootArea"
      },
      children: [
        jsCreateElement('div', {
          attrs: {
            id: "root"
          }
        })
      ]
    });
    rawModalLoader(jsRender(html));
    dqs(".modalpop").classList.add("confirmclose");
  }

  dqs(".modalpop>div").style.paddingTop = "0";
  emailbuilderLoad(() => {
    if (purpose === 'clear') {
      let defaultJson = JSON.stringify(emailbuilderAddonClearJSON);
      emailbuilderClear(defaultJson);
      emailbuilderLoadedJSON = defaultJson;

      dqs(".modalpop").classList.remove("hasjson");
      dqs(".modalpop").classList.add("emailbuilder");
    } else if (purpose === 'setJSON') {
      try {
        let parsedData = JSON.parse(globalMailEditorContent);
        emailbuilderAddonSetJson(globalMailEditorContent);
        emailbuilderLoadedJSON = parsedData;
      } catch (error) {
        console.error("Invalid JSON data, reverting to default JSON. Error:", error);
        let defaultJson = JSON.stringify(emailbuilderAddonClearJSON);
        emailbuilderClear(defaultJson);
        emailbuilderLoadedJSON = defaultJson;
      }

      dqs(".modalpop").classList.add("hasjson");
      dqs(".modalpop").classList.add("emailbuilder");
    }
  });
}


function mailToggleHTMLEditor() {
  dqs("#mailEditContent").classList.toggle("hideme");
  dqs("#mailEditPreviewHTML").classList.toggle("hideme");

  dqs("#mailEditPreviewHTML").innerHTML = dqs("#mailEditContent").value;

  if (!dqs("#mailEditContent").classList.contains("hideme")) {
    dqs("#mailEditContent").focus();
    dqs(".editMailButtonInner").innerText = "Show preview";
  } else {
    dqs(".editMailButtonInner").innerText = "Edit mail";
  }
}


function switchEditor() {
  const html = jsCreateElement('div', {
    attrs: {
      style: "width: 300px;"
    },
    children: [
      jsCreateElement('div', {
        attrs: {
          class: 'headingH3 mb20 center'
        },
        children: ['Switch editor']
      }),
      jsCreateElement('div', {
        attrs: {
          class: 'mb20 center'
        },
        children: ['This will delete all changes made in the current editor.']
      }),
      jsCreateElement('input', {
        attrs: {
          type: 'text',
          class: 'mb20',
          id: 'switchConfirm',
          placeholder: 'Type "switch" to confirm',
          value: ''
        }
      }),
      jsCreateElement('div', {
        attrs: {
          class: 'itemBlock mb20'
        },
        children: [
          jsCreateElement('button', {
            attrs: {
              class: 'buttonIcon',
              onclick: 'switchEditorDo()'
            },
            rawHtml: [
              '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="size-6"><path stroke-linecap="round" stroke-linejoin="round" d="M12 9v6m3-3H9m12 0a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" /></svg><div class="ml5">Switch editor</div>'
            ]
          })
        ]
      })
    ]
  });
  rawModalLoader(jsRender(html));
  labelFloater();
}

function switchEditorDo() {
  if (dqs("#switchConfirm").value !== "switch") {
    rawModalError("Invalid confirmation");
    return;
  }
  globalMailEditorType = globalMailEditorType === "emailbuilder" ? "html" : "emailbuilder";
  dqs(".mailSave").classList.add("active");
  saveMail(globalMailData.id);
  setTimeout(() => {
    loadMail(globalMailData.id);
    dqs(".modalpop").remove();
  }, 1000);
}


async function saveMail(mailID) {
  // if (!dqs(".mailSave").classList.contains("active")) {
  //   return;
  // }

  let
    name = dqs("#mailEditName").value,
    identifier = dqs("#mailEditIdentifier").value,
    subject = dqs("#mailEditSubject").value,
    tags = dqs("#mailEditTags").value,
    category = dqs("#mailEditCategory").value,
    sendOnce = dqs("#sendOnce").checked;

  // Check if user is trying to archive an email that's used in flows
  const previousCategory = globalMailData ? globalMailData.category : null;
  if (category === "archived" && previousCategory !== "archived") {
    // Check if email is used in flows
    const flowCheck = await fetch("/api/mails/check_flows?mailID=" + mailID, {
      method: "GET"
    })
    .then(manageErrors)
    .then(response => response.json());

    if (flowCheck.used_in_flows && flowCheck.count > 0) {
      // Show warning and require confirmation
      const flowNames = flowCheck.flow_steps.map(fs => fs.flow_name).join(", ");
      const confirmed = await confirmArchiveMailInFlows(mailID, name, flowCheck.count, flowNames);
      if (!confirmed) {
        // User cancelled, revert category dropdown
        dqs("#mailEditCategory").value = previousCategory || "";
        return;
      }
    }
  }

  let
    contentHTML,
    contentEditor,
    skipContent = false;

  if (globalMailEditorType == "html" || globalMailEditorType == "") {
    contentHTML = dqs("#mailEditContent").value;
    contentEditor = "";
  } else {
    contentHTML = typeof emailbuilderAddonGetHTML === 'function' ? emailbuilderAddonGetHTML() : '';
    contentEditor = typeof emailbuilderAddonGetJson === 'function' ? emailbuilderAddonGetJson() : '';
    emailbuilderLoadedJSON = contentEditor;
    if (contentEditor == "") {
      skipContent = true;
    } else {
      dqs("#mailEditPreviewHTML").innerHTML = contentHTML;
    }
    // contentHTML = emailbuilderAddonGetHTML();
    // contentEditor = emailbuilderAddonGetJson();
  }

  fetch("/api/mails/update", {
    method: "POST",
    body: new URLSearchParams({
      mailID: mailID,
      name: name,
      identifier: identifier,
      subject: subject,
      tags: tags,
      category: category,
      sendOnce: sendOnce,
      contentHTML: contentHTML,
      contentEditor: contentEditor,
      editorType: globalMailEditorType,
      skipContent: skipContent
    })
  })
  .then(manageErrors)
  .then(() => {
    dqs(".mailSave").classList.remove("active");
    // Update globalMailData to reflect the new category
    if (globalMailData) {
      globalMailData.category = category;
    }
  });
}

async function duplicateMail(mailID) {
  let mailData = await fetch("/api/mails/duplicate?mailID=" + mailID, {
    method: "POST"
  })
  .then(manageErrors)
  .then(response => response.json())
  .then(data => {
    window.location.href = "/mails?viewMail=" + data.id;
  });

  console.log(mailData);
}

async function sendMail(mailID) {
  let lists = await fetch("/api/lists/all", {
    method: "GET"
  })
  .then(manageErrors)
  .then(response => response.json())
  .then(data => {
    return data.data;
  });

  let listOpt = lists.map(list => {
    return jsCreateElement('option', {
      attrs: {
        value: list.id
      },
      children: [list.name]
    });
  });
  listOpt.push(jsCreateElement('option', {
      attrs: {
        value: '',
        selected: true
      },
      children: ['Select list']
    })
  );

  // Send test mail (input email) or select from list and send
  const html = jsCreateElement('div', {
    attrs: {
      style: "width: 300px;"
    },
    children: [
      jsCreateElement('div', {
        attrs: {
          class: 'headingH3 mb20 center'
        },
        children: ['Send mail']
      }),
      jsCreateElement('div', {
        attrs: {
          class: 'itemBlock mb40'
        },
        children: [
          jsCreateElement('label', {
            attrs: {
              class: 'forinput'
            },
            children: ['Send to list']
          }),
          jsCreateElement('select', {
            attrs: {
              id: 'mailSendToList',
              class: 'mb20'
            },
            children: listOpt
          }),
          jsCreateElement('input', {
            attrs: {
              type: 'text',
              id: 'mailToListValidate',
              autocomplete: 'off',
              class: 'mb20',
              placeholder: 'Write CONFIRM to send'
            }
          }),
          jsCreateElement('div', {
            children: [
              jsCreateElement('button', {
                attrs: {
                  class: 'buttonIcon',
                  onclick: 'sendMailListDo(' + mailID + ')'
                },
                rawHtml: [
                  '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="size-6"><path stroke-linecap="round" stroke-linejoin="round" d="M21.75 6.75v10.5a2.25 2.25 0 0 1-2.25 2.25h-15a2.25 2.25 0 0 1-2.25-2.25V6.75m19.5 0A2.25 2.25 0 0 0 19.5 4.5h-15a2.25 2.25 0 0 0-2.25 2.25m19.5 0v.243a2.25 2.25 0 0 1-1.07 1.916l-7.5 4.615a2.25 2.25 0 0 1-2.36 0L3.32 8.91a2.25 2.25 0 0 1-1.07-1.916V6.75" /></svg><div class="ml5">Send email</div>'
                ]
              })
            ]
          })
        ]
      }),
      jsCreateElement('div', {
        attrs: {
          class: 'itemBlock mb20'
        },
        children: [
          jsCreateElement('label', {
            attrs: {
              class: 'forinput'
            },
            children: ['Send to email']
          }),
          jsCreateElement('input', {
            attrs: {
              type: 'text',
              id: 'mailSendToEmail',
              class: 'mb20'
            }
          }),
          jsCreateElement('div', {
            children: [
              jsCreateElement('button', {
                attrs: {
                  class: 'buttonIcon',
                  onclick: 'sendMailPersonDo(' + mailID + ')'
                },
                rawHtml: [
                  '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="size-6"><path stroke-linecap="round" stroke-linejoin="round" d="M21.75 6.75v10.5a2.25 2.25 0 0 1-2.25 2.25h-15a2.25 2.25 0 0 1-2.25-2.25V6.75m19.5 0A2.25 2.25 0 0 0 19.5 4.5h-15a2.25 2.25 0 0 0-2.25 2.25m19.5 0v.243a2.25 2.25 0 0 1-1.07 1.916l-7.5 4.615a2.25 2.25 0 0 1-2.36 0L3.32 8.91a2.25 2.25 0 0 1-1.07-1.916V6.75" /></svg><div class="ml5">Send email</div>'
                ]
              })
            ]
          })
        ]
      }),
    ]
  });

  rawModalLoader(jsRender(html));
  labelFloater();
}


function sendMailListDo(mailID) {
  let listID = dqs("#mailSendToList").value;
  let validate = dqs("#mailToListValidate").value;

  if (validate !== "CONFIRM") {
    rawModalError("Invalid confirmation");
    return;
  }

  fetch("/api/mails/send", {
    method: "POST",
    body: new URLSearchParams({
      mailID: mailID,
      listID: listID
    })
  })
  .then(manageErrors)
  .then(() => {
    rawModalSuccess();
  });
}

function sendMailPersonDo(mailID) {
  let email = dqs("#mailSendToEmail").value;

  fetch("/api/mails/send", {
    method: "POST",
    body: new URLSearchParams({
      mailID: mailID,
      email: email
    })
  })
  .then(manageErrors)
  .then(() => {
    rawModalSuccess();
  });
}

// -- Confirm archiving email that's used in flows
function confirmArchiveMailInFlows(mailID, mailName, flowCount, flowNames) {
  return new Promise((resolve) => {
    const html = jsCreateElement('div', {
      attrs: {
        style: "width: 500px;"
      },
      children: [
        jsCreateElement('div', {
          attrs: {
            class: 'headingH3 mb20 center'
          },
          children: ['WARNING: Email Used in Flows']
        }),
        jsCreateElement('div', {
          attrs: {
            style: "font-size: 12px;margin:20px;",
            class: 'center'
          },
          rawHtml: [
            '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="size-6"><path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126ZM12 15.75h.007v.008H12v-.008Z" /></svg><br>You are about to archive the email "<b>' + mailName + '</b>" which is currently used in <b>' + flowCount + '</b> flow step(s).'
          ]
        }),
        jsCreateElement('div', {
          attrs: {
            style: "font-size: 12px;margin:20px;"
          },
          children: [
            'This email is used in the following flow(s): ' + flowNames
          ]
        }),
        jsCreateElement('div', {
          attrs: {
            style: "font-size: 12px;margin:20px;",
            class: 'center'
          },
          rawHtml: [
            '<b>Archiving this email could result in sending emails that were meant to be archived if the flow steps are modified.</b>'
          ]
        }),
        jsCreateElement('div', {
          attrs: {
            style: "font-size: 12px;margin:20px;"
          },
          children: [
            'Please type CONFIRM to proceed with archiving this email.'
          ]
        }),
        jsCreateElement('input', {
          attrs: {
            type: 'text',
            id: 'mailArchiveValidate',
            placeholder: 'Write CONFIRM to continue',
            oninput: 'if(this.value == "CONFIRM"){dqs("#mailArchiveButton").disabled = false;} else {dqs("#mailArchiveButton").disabled = true;}',
            class: 'mb20'
          }
        }),
        jsCreateElement('div', {
          children: [
            jsCreateElement('button', {
              attrs: {
                id: 'mailArchiveButton',
                class: 'svg30 w100p',
                onclick: 'confirmArchiveMailInFlowsDo()',
                disabled: true
              },
              rawHtml: [
                '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="size-6"><path stroke-linecap="round" stroke-linejoin="round" d="M12 9v6m3-3H9m12 0a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" /></svg><div style="margin-left: 5px;">Confirm archive</div>'
              ]
            })
          ]
        }),
        jsCreateElement('div', {
          children: [
            jsCreateElement('button', {
              attrs: {
                class: 'buttonIcon mt20',
                onclick: 'cancelArchiveMailInFlows()'
              },
              rawHtml: [
                '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="size-6"><path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" /></svg><div style="margin-left: 5px;">Cancel</div>'
              ]
            })
          ]
        })
      ]
    });

    // Store the resolve function
    window._archiveMailResolve = resolve;

    rawModalLoader(jsRender(html));
    setTimeout(() => {
      dqs("#mailArchiveValidate").focus();
      labelFloater();
    }, 100);
  });
}

function confirmArchiveMailInFlowsDo() {
  let validate = dqs("#mailArchiveValidate").value;

  if (validate !== "CONFIRM") {
    rawModalError("Invalid confirmation");
    return;
  }

  // Close the modal
  dqs(".modalpop").remove();

  // Resolve the promise with true (confirmed)
  if (window._archiveMailResolve) {
    window._archiveMailResolve(true);
    window._archiveMailResolve = null;
  }
}

function cancelArchiveMailInFlows() {
  // Close the modal
  dqs(".modalpop").remove();

  // Resolve the promise with false (cancelled)
  if (window._archiveMailResolve) {
    window._archiveMailResolve(false);
    window._archiveMailResolve = null;
  }
}