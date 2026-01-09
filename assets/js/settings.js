
function buildSettingsHtml() {
  // Three tab buttons: SMTP, API, Webhooks
  const html = jsCreateElement('div', {
    children: [
      jsCreateElement('div', {
        attrs: {
          class: 'tabButtons',
          style: 'display: grid ; grid-template-columns: 1fr 1fr 1fr 1fr 1fr; width: 600px; grid-gap: 30px; margin-bottom: 60px; height: 40px;'
        },
        children: [
          jsCreateElement('button', {
            attrs: {
              class: 'tabButton w100p',
              onclick: 'showTab("main")'
            },
            children: ['Main']
          }),
          jsCreateElement('button', {
            attrs: {
              class: 'tabButton w100p',
              onclick: 'showTab("smtp")'
            },
            children: ['SMTP']
          }),
          jsCreateElement('button', {
            attrs: {
              class: 'tabButton w100p',
              onclick: 'showTab("api")'
            },
            children: ['API']
          }),
          jsCreateElement('button', {
            attrs: {
              class: 'tabButton w100p',
              onclick: 'showTab("webhooks")'
            },
            children: ['Webhooks']
          }),
          jsCreateElement('button', {
            attrs: {
              class: 'tabButton w100p',
              onclick: 'showTab("users")'
            },
            children: ['Users']
          })
        ]
      }),
      jsCreateElement('div', {
        attrs: {
          id: 'tabContent',
          style: 'padding: 30px; border: 1px solid var(--colorN40); width: calc(600px - 60px); border-radius: 10px;'
        }
      })
    ]
  });

  dqs("#heading").innerText = "Settings";
  dqs("#work").innerHTML = "";

  let tabs = jsRender(html);
  dqs("#work").appendChild(tabs);

  showTab("main");
}


function showTab(tab) {
  let tabContent = dqs("#tabContent");
  tabContent.innerHTML = "";

  if (tab == "main") {
    buildSettingsMain().then((html) => {
      tabContent.appendChild(jsRender(jsCreateElement('div', { attrs: { style: "" }, children: html })));
      labelFloater();
    });
  }

  if (tab == "smtp") {
    buildSettingsSMTP().then((html) => {
      tabContent.appendChild(jsRender(jsCreateElement('div', { attrs: { style: "" }, children: html })));
      labelFloater();
    });
  }

  if (tab == "api") {
    buildSettingsAPI().then((html) => {
      tabContent.appendChild(jsRender(jsCreateElement('div', { attrs: { style: "" }, children: html })));
      labelFloater();

      var objTableApi = new Tabulator("#apiTable", {
        height: '500px',
        layout:"fitColumns",
        ajaxURL:"/api/settings/api",
        progressiveLoad:"load",
        columns:[
          { title: "Name", field: "name" },
          { title: "Count", field: "count" },
          { title: "ID", field: "id" },
          { title: "Created At", field: "created_at" }
        ]
      });

      objTableApi.on("rowClick", function(e, row){
        updateAPI(row.getData().id);
      });

      // Add CSV download context menu
      addTabulatorContextMenu(objTableApi, "api_keys.csv");

    });
  }

  if (tab == "webhooks") {
    buildSettingsWebhooks().then((html) => {
      tabContent.appendChild(jsRender(jsCreateElement('div', { attrs: { style: "" }, children: html })));
      labelFloater();

      var objTableWebhooks = new Tabulator("#webhookTable", {
        height: '500px',
        layout:"fitColumns",
        ajaxURL:"/api/settings/webhooks",
        progressiveLoad:"load",
        columns:[
          { title: "ID", field: "id", visible: false },
          { title: "Name", field: "name" },
          { title: "URL", field: "url" },
          { title: "Event", field: "event" },
          { title: "Created At", field: "created_at" }
        ]
      });

      objTableWebhooks.on("rowClick", function(e, row){
        deleteWebhook(row.getData().id);
      });

      // Add CSV download context menu
      addTabulatorContextMenu(objTableWebhooks, "webhooks.csv");

    });
  }

  if (tab == "users") {
    buildSettingsUsers().then((html) => {
      tabContent.appendChild(jsRender(jsCreateElement('div', { attrs: { style: "" }, children: html })));
      labelFloater();

      var objTableUsers = new Tabulator("#usersTable", {
        height: '500px',
        layout:"fitColumns",
        ajaxURL:"/api/settings/users",
        progressiveLoad:"load",
        columns:[
          { title: "ID", field: "id", visible: false },
          { title: "Email", field: "email" },
          { title: "Created At", field: "created_at" },
          { title: "Delete", field: "delete", width: 40 }
        ]
      });

      objTableUsers.on("cellClick", function(e, cell){
        if (cell.getColumn().getField() == "delete") {
          deleteUser(cell.getData().id);
        }
      });

      // Add CSV download context menu
      addTabulatorContextMenu(objTableUsers, "users.csv");
    });

  }
}

/*

Main

*/
async function buildSettingsMain() {
  // We get two things - the page name, optin email id, if logo is uploaded
  let settings = await fetch('/api/settings/main').then(res => res.json());

  let html = [];
  let optinEmailID = "";
  // Loop values and create jsCreateElements
  settings.forEach((item, i) => {
    if (['optinEmailID', 'optinEmailName'].includes(item.key)) {
      if (item.key == 'optinEmailID') {
        optinEmailID = item.value;
      }
    } else {
      html.push(
        jsCreateElement('div', {
          attrs: {
            class: 'itemBlock mb20'
          },
          children: [
            jsCreateElement('label', {
              attrs: {
                class: 'forinput'
              },
              children: [item.name]
            }),
            jsCreateElement('input', {
              attrs: {
                id: item.key,
                value: item.value
              }
            })
          ]
        })
      );
    }
  });


  let mails = await fetch("/api/mails/all")
  .then(response => response.json())
  .then(data => data.data);

  let mailsOpts = [];

  mails.forEach(mail => {
    mailsOpts.push(jsCreateElement('option', {
      attrs: {
        value: mail.id,
        selected: (mail.id == optinEmailID) ? "selected" : false
      },
      children: [ mail.category + ' - ' + mail.name + ' (' + mail.identifier + ')' ]
    }));
  });

  html.push(
    jsCreateElement('div', {
      attrs: {
        class: 'itemBlock mb20'
      },
      children: [
        jsCreateElement('label', {
          attrs: {
            class: 'forinput'
          },
          children: ['Optin Email']
        }),
        jsCreateElement('select', {
          attrs: {
            id: 'optinEmailID',
          },
          children: mailsOpts
        })
      ]
    })
  );



  html.push(jsCreateElement('button', {
    attrs: {
      id: 'main_settings',
      class: 'buttonIcon mt30',
      onclick: 'saveSettingsMain()'
    },
    rawHtml: [
      '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="size-6"><path stroke-linecap="round" stroke-linejoin="round" d="M12 9v6m3-3H9m12 0a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" /></svg><div class="ml10">Save</div>'
    ]
  }));

  return html;
}


/*

  Main

*/
function saveSettingsMain() {
  fetch('/api/settings/main', {
    method: 'POST',
    body: new URLSearchParams({
      pageName: dqs("#pageName").value,
      hostname: dqs("#hostname").value,
      logoUrl: dqs("#logoUrl").value,
      optinEmailID: dqs("#optinEmailID").value,
      linkSuccess: dqs("#linkSuccess").value
    })
  })
  .then(manageErrors)
}



/*

SMTP

*/
async function buildSettingsSMTP() {
  let smptSettings = await fetch('/api/settings/smtp').then(res => res.json());

  let html = [];
  // Loop values and create jsCreateElements
  smptSettings.forEach((item, i) => {
    html.push(
      jsCreateElement('div', {
        attrs: {
          class: 'itemBlock mb20'
        },
        children: [
          jsCreateElement('label', {
            attrs: {
              class: 'forinput'
            },
            children: [item.name]
          }),
          jsCreateElement('input', {
            attrs: {
              style: 'min-height: 32px;',
              id: item.key,
              value: item.value,
              checked: (item.key == 'smtpUseAwsSes') ? item.value : false,
              disabled: (item.key == 'smtpStorage') ? true : false,
              type: (item.key == 'smtpPass') ? 'password' : ((item.key == 'smtpUseAwsSes') ? 'checkbox' : 'text')
            }
          })
        ]
      })
    );
  });

  html.push(jsCreateElement('button', {
    attrs: {
      id: 'smtp_settings',
      class: 'buttonIcon mt30',
      onclick: 'saveSettingsSMTP()'
    },
    rawHtml: [
      '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="size-6"><path stroke-linecap="round" stroke-linejoin="round" d="M12 9v6m3-3H9m12 0a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" /></svg><div class="ml10">Save</div>'
    ]
  }));

  return html;
}


async function saveSettingsSMTP() {
  let smptSettings = await fetch('/api/settings/smtp').then(res => res.json());

  let data = {};
  smptSettings.forEach((item, i) => {
    if (item.key == 'smtpUseAwsSes') {
      data[item.key] = document.getElementById(item.key).checked ? "true" : "false";
    } else {
      data[item.key] = document.getElementById(item.key).value;
    }
  });

  fetch('/api/settings/smtp', {
    method: 'POST',
    body: new URLSearchParams(data)
  })
  .then(manageErrors)
  .then(() => {
    window.location.reload();
  })
}




/*

API

*/
async function buildSettingsAPI() {
  let apiSettings = await fetch('/api/settings/api').then(res => res.json());

  let html = [];

  html.push(
    jsCreateElement('div', {
      attrs: {
        class: 'itemBlock mb20'
      },
      children: [
        jsCreateElement('label', {
          attrs: {
            class: 'forinput'
          },
          children: ["API key"]
        }),
        jsCreateElement('input', {
          attrs: {
            id: 'apiKeyName',
            value: '',
            placeholder: 'Enter name'
          }
        }),
        jsCreateElement('button', {
          attrs: {
            id: 'api_key',
            class: 'buttonIcon mt20 mb40',
            onclick: 'addAPI()'
          },
          rawHtml: [
            '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="size-6"><path stroke-linecap="round" stroke-linejoin="round" d="M12 9v6m3-3H9m12 0a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" /></svg><div class="ml10">Add new API key</div>'
          ]
        })
      ]
    })
  )

  html.push(
    jsCreateElement('div', {
      attrs: {
        id: 'apiTable'
      }
    })
  );


  return html;
}


function addAPI() {
  if (dqs("#apiKeyName").value == "") {
    alert("Please enter a name for the API key");
    return;
  }

  fetch('/api/settings/api/new', {
    method: 'POST',
    body: new URLSearchParams({
      apiName: dqs("#apiKeyName").value
    })
  })
  .then(manageErrors)
  .then(response => response.json())
  .then(data => {
    console.log(data);
    rawModalSuccess("API key: " + data.key);
  });
}


function updateAPI(ident) {
  // Create input element
  const html = jsCreateElement('div', {
      attrs: {
      },
      children: [
        jsCreateElement('div', {
          attrs: {
            class: 'headingH3 mb20'
          },
          children: ["Regenerate API key"]
        }),
        jsCreateElement('button', {
          attrs: {
            id: ident,
            class: "buttonIcon",
            onclick: 'updateAPIDo("' + ident + '")'
          },
          rawHtml: [
            '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="size-6"><path stroke-linecap="round" stroke-linejoin="round" d="M16.023 9.348h4.992v-.001M2.985 19.644v-4.992m0 0h4.992m-4.993 0 3.181 3.183a8.25 8.25 0 0 0 13.803-3.7M4.031 9.865a8.25 8.25 0 0 1 13.803-3.7l3.181 3.182m0-4.991v4.99" /></svg><div class="ml10">Regenerate</div>'
          ]
        }),
        jsCreateElement('hr'),
        jsCreateElement('div', {
          attrs: {
            class: 'headingH3 mb20'
          },
          children: ["Delete API key"]
        }),
        jsCreateElement('button', {
          attrs: {
            id: ident,
            class: "buttonIcon",
            onclick: 'deleteAPIDo("' + ident + '")'
          },
          rawHtml: [
            '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="size-6"><path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" /></svg><div class="ml10">Delete</div>'
          ]
        })
      ]
    });

  rawModalLoader(jsRender(html));
}


function updateAPIDo(ident) {
  fetch('/api/settings/api/update', {
    method: 'POST',
    body: new URLSearchParams({
      ident: ident
    })
  })
  .then(manageErrors)
  .then(() => {
    window.location.reload();
  });
}


function deleteAPIDo(ident) {
  fetch('/api/settings/api/delete?ident=' + ident, {
    method: 'DELETE'
  })
  .then(manageErrors)
  .then(() => {
    window.location.reload();
  });
}


/*

Webhooks

*/

async function buildSettingsWebhooks() {
  // let webhooks = await fetch('/api/settings/webhooks').then(res => res.json());

  let hooks = [
    'contact_created', 'contact_updated',
    // 'contact_deleted',
    // 'contact_subscribed',
    // 'contact_unsubscribed',
    'contact_optedin', 'contact_optedout',
    // 'email_sent',
    'email_opened',
    'email_clicked',
    'email_bounced', 'email_complained',
  ];
  let hookOptions = [];
  hooks.forEach((item, i) => {
    hookOptions.push(jsCreateElement('option', {
      attrs: {
        value: item
      },
      children: [item]
    }));
  });

  let html = [];

  html.push(
    jsCreateElement('div', {
      attrs: {
        class: 'mb40'
      },
      children: [
        jsCreateElement('div', {
          attrs: {
            class: 'itemBlock mb20'
          },
          children: [
            jsCreateElement('label', {
              attrs: {
                class: 'forinput'
              },
              children: ["Webhook Name"]
            }),
            jsCreateElement('input', {
              attrs: {
                id: 'webhookName',
                value: '',
                placeholder: 'Enter name',
                class: ''
              }
            }),
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
              children: ["Webhook URL"]
            }),
            jsCreateElement('input', {
              attrs: {
                id: 'webhookURL',
                value: '',
                placeholder: 'Enter URL',
                class: ''
              }
            }),
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
              children: ["Webhook Headers"]
            }),
            jsCreateElement('input', {
              attrs: {
                id: 'webhookHeaders',
                value: '[{"type":"Content-Type","value":"application/json"}]',
                placeholder: '[{"type":"Content-Type","value":"application/json"}]',
                class: ''
              }
            }),
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
              children: ["Webhook Event"]
            }),
            jsCreateElement('select', {
              attrs: {
                id: 'webhookEvent',
                class: ''
              },
              children: hookOptions
            }),
          ]
        }),
        jsCreateElement('button', {
          attrs: {
            id: 'webhook_url',
            class: 'buttonIcon',
            onclick: 'addWebhook()'
          },
          rawHtml: [
            '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="size-6"><path stroke-linecap="round" stroke-linejoin="round" d="M12 9v6m3-3H9m12 0a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" /></svg><div class="ml10">Add new webhook</div>'
          ]
        })
      ]
    })
  );

  html.push(
    jsCreateElement('div', {
      attrs: {
        id: 'webhookTable'
      }
    })
  );

  return html;
}


function deleteWebhook(ident) {
  // Create input element
  const html = jsCreateElement('div', {
      attrs: {
      },
      children: [
        jsCreateElement('div', {
          attrs: {
            class: 'headingH3 mb20'
          },
          children: ["Delete webhook"]
        }),
        jsCreateElement('button', {
          attrs: {
            id: ident,
            class: "buttonIcon",
            onclick: 'deleteWebhookDo("' + ident + '")'
          },
          rawHtml: [
            '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="size-6"><path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" /></svg><div class="ml10">Delete</div>'
          ]
        })
      ]
    });

  rawModalLoader(jsRender(html));
}


function deleteWebhookDo(ident) {
  fetch('/api/settings/webhooks/delete', {
    method: 'POST',
    body: new URLSearchParams({
      ident: ident
    })
  })
  .then(manageErrors)
  .then(() => {
    window.location.reload();
  });
}


function addWebhook() {
  if (dqs("#webhookName").value == "") {
    alert("Please enter a name for the webhook");
    return;
  }

  if (dqs("#webhookURL").value == "") {
    alert("Please enter a URL for the webhook");
    return;
  }

  fetch('/api/settings/webhooks/new', {
    method: 'POST',
    body: new URLSearchParams({
      webhookName: dqs("#webhookName").value,
      webhookURL: dqs("#webhookURL").value,
      webhookEvent: dqs("#webhookEvent").value,
      webhookHeaders: dqs("#webhookHeaders").value
    })
  })
  .then(manageErrors)
  .then(() => {
    window.location.reload();
  });
}



/*

Users

*/

async function buildSettingsUsers() {

  let html = [];

  html.push(
    jsCreateElement('div', {
      attrs: {
        class: 'mb40'
      },
      children: [
        jsCreateElement('div', {
          attrs: {
            class: 'itemBlock mb20'
          },
          children: [
            jsCreateElement('label', {
              attrs: {
                class: 'forinput'
              },
              children: ["Email"]
            }),
            jsCreateElement('input', {
              attrs: {
                id: 'userEmail',
                value: '',
                placeholder: 'Enter email',
                class: ''
              }
            }),
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
              children: ["Password"]
            }),
            jsCreateElement('input', {
              attrs: {
                id: 'userPassword',
                value: '',
                placeholder: 'Enter password',
                class: ''
              }
            }),
          ]
        }),
        jsCreateElement('button', {
          attrs: {
            id: 'user_create',
            class: 'buttonIcon',
            onclick: 'createUser()'
          },
          rawHtml: [
            '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="size-6"><path stroke-linecap="round" stroke-linejoin="round" d="M12 9v6m3-3H9m12 0a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" /></svg><div class="ml10">Add new user</div>'
          ]
        })
      ]
    })
  );

  html.push(
    jsCreateElement('div', {
      attrs: {
        id: 'usersTable'
      }
    })
  );

  return html;
}

function deleteUser(id) {
  const html = jsCreateElement('div', {
    attrs: {
    },
    children: [
      jsCreateElement('div', {
        attrs: {
          class: 'headingH3 mb20'
        },
        children: ["Delete user"]
      }),
      jsCreateElement('button', {
        attrs: {
          class: "buttonIcon",
          onclick: 'deleteUserDo("' + id + '")'
        },
        rawHtml: [
          '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="size-6"><path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" /></svg><div class="ml10">Delete</div>'
        ]
      })
    ]
  });

  rawModalLoader(jsRender(html));
}

function deleteUserDo(id) {
  fetch('/api/users/delete?userID=' + id, {
    method: 'DELETE'
  })
  .then(manageErrors)
  .then(() => {
    window.location.reload();
  });
}

function createUser() {
  fetch('/api/users/create', {
    method: 'POST',
    body: new URLSearchParams({
      email: dqs("#userEmail").value,
      password: dqs("#userPassword").value
    })
  })
  .then(manageErrors)
  .then(() => {
    window.location.reload();
  });
}