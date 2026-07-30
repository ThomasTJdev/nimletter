

let
  globalContact,
  globalContactID;

// Patch a single contacts-table row instead of reloading the full list.
function updateContactsTableRow(fields) {
  if (!objTableContacts || globalContactID == null) {
    return;
  }
  const row =
    objTableContacts.getRow(String(globalContactID)) ||
    objTableContacts.getRow(Number(globalContactID));
  if (row) {
    row.update(fields);
  }
}

// Keep the open contact's table row in sync after the detail panel reloads.
function syncContactsTableRowFromGlobal() {
  if (!globalContact) {
    return;
  }
  const subscribedLists = (globalContact.subscriptions || [])
    .map(item => item.list_name)
    .join(", ");
  updateContactsTableRow({
    uuid: globalContact.uuid,
    email: globalContact.email,
    name: globalContact.name,
    status: globalContact.status,
    requires_double_opt_in: globalContact.requires_double_opt_in,
    double_opt_in: globalContact.double_opt_in,
    country: (globalContact.meta && globalContact.meta.country) || "",
    subscribed_lists: subscribedLists,
    has_unsubscribed: globalContact.has_unsubscribed,
    unsubscribed_at: globalContact.unsubscribed_at
      ? String(globalContact.unsubscribed_at).split(".")[0]
      : "",
    unscribed_from_lists: globalContact.unscribed_from_lists || "",
    bounced_at: globalContact.bounced_at
      ? String(globalContact.bounced_at).split(".")[0]
      : "",
    complained_at: globalContact.complained_at
      ? String(globalContact.complained_at).split(".")[0]
      : "",
    updated_at: globalContact.updated_at
      ? String(globalContact.updated_at).split(".")[0]
      : "",
  });
}

// -- Create contact
function addContact() {
  const html = jsCreateElement('div', {
    attrs: {
      style: "width: 300px;"
    },
    children: [
      jsCreateElement('div', {
        attrs: {
          class: 'headingH3 mb20 center'
        },
        children: ['Add contact']
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
            children: ['Name']
          }),
          jsCreateElement('input', {
            attrs: {
              id: 'contactNewName'
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
            children: ['Email']
          }),
          jsCreateElement('input', {
            attrs: {
              type: 'email',
              id: 'contactNewEmail'
            }
          })
        ]
      }),
      jsCreateElement('div', {
        attrs: {
          style: "font-size: 12px;"
        },
        children: [
          'Requiring double opt-in will auto-send a confirmation email to the user.'
        ]
      }),
      jsCreateElement('div', {
        attrs: {
          style: 'display: flex;align-items: center;margin: 10px 0 30px;'
        },
        children: [
          jsCreateElement('label', {
            attrs: {
              class: 'toggleSwitch compact',
            },
            children: [
              jsCreateElement('input', {
                attrs: {
                  type: 'checkbox',
                  id: 'requiresDoubleOptInNew'
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
            children: [
              'Require double opt-in'
            ]
          })
        ]
      }),
      jsCreateElement('div', {
        children: [
          jsCreateElement('button', {
            attrs: {
              class: 'svg30 w100p',
              onclick: 'addContactDo()'
            },
            rawHtml: [
              '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="size-6"><path stroke-linecap="round" stroke-linejoin="round" d="M12 9v6m3-3H9m12 0a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" /></svg><div style="margin-left: 5px;">Add contact</div>'
            ]
          })
        ]
      })
    ]
  });
  rawModalLoader(jsRender(html));
  setTimeout(() => {
    labelFloater();
    dqs("#contactNewEmail").focus();
  }, 100);
}

function addContactDo() {
  let
    email = dqs("#contactNewEmail").value,
    name = dqs("#contactNewName").value,
    requiresDoubleOptIn = dqs("#requiresDoubleOptInNew").checked;

  fetch("/api/contacts/create", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      email: email,
      name: name,
      requiresDoubleOptIn: requiresDoubleOptIn
    })
  })
  .then(manageErrors)
  .then(response => response.json())
  .then(data => {
    if (data.success == true) {
      dqs(".modalpop").remove();
      // Add the new row locally — avoid refetching the entire contacts list.
      if (objTableContacts) {
        const now = new Date().toISOString().slice(0, 19).replace("T", " ");
        objTableContacts.addData([{
          id: String(data.id),
          uuid: data.uuid || "",
          email: email,
          name: name,
          status: "enabled",
          requires_double_opt_in: requiresDoubleOptIn,
          double_opt_in: false,
          country: (data.meta && data.meta.country) || "",
          subscribed_lists: "",
          has_unsubscribed: false,
          unsubscribed_at: "",
          unscribed_from_lists: "",
          bounced_at: "",
          complained_at: "",
          created_at: now,
          updated_at: now,
        }], true);
      }
      loadContact(data.id);
    }
  });

}

// -- Contact
function loadContact(contactID) {

  globalContactID = contactID;
  globalContact = null;

  // 1 Create modal which floats quickly in from the right
  // 2 Fetch the contact data
  // 3 Display the contact data in the modal

  const html = jsCreateElement('div', {
    attrs: {
      id: 'contact',
      class: "modal"
    }
  });

  if (dqs('#contact')) {
    dqs('#contact').innerHTML = '';
  } else {
    dqs('#work').append(jsRender(html));
  }


  fetch("/api/contacts/get?contactID=" + contactID, {
    method: "GET",
    headers: {
      "Content-Type": "application/json",
    }
  })
  .then(manageErrors)
  .then(response => response.json())
  .then(data => {
    globalContact = data.data[0];
    buildContactHTML(globalContact);
    syncContactsTableRowFromGlobal();
  });

}

function buildContactHTML(data) {

  let metaData = [];
  for (const [key, value] of Object.entries(data.meta)) {
    metaData.push(createMetaHTML(key, value));
  }

  let subscriptions = [];
  for (var i = 0; i < data.subscriptions.length; i++) {
    subscriptions.push(
      createSubcriptionHTML(data.subscriptions[i].list_id, "subscribed", data.subscriptions[i].list_name, data.subscriptions[i].subscribed_at.split(".")[0])
    );
  }

  let pendingLists = [];
  for (var i = 0; i < data.pending_lists.length; i++) {
    pendingLists.push(
      createSubcriptionHTML(data.pending_lists[i].id, "pending", data.pending_lists[i].list_name, data.pending_lists[i].created_at.split(".")[0])
    );
  }


  const html = jsCreateElement('div', {
    attrs: {
      id: 'contactArea',
    },
    children: [
      // Top block
      jsCreateElement('div', {
        attrs: {
          style: 'display: flex;justify-content: space-between;'
        },
        children: [
          jsCreateElement('div', {
            attrs: {
              class: 'topblock',
              style: 'margin-bottom: 40px;'
            },
            children: [
              jsCreateElement('div', {
                attrs: {
                  class: "svg30 mr10"
                },
                rawHtml: [
                  '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="size-6"><path stroke-linecap="round" stroke-linejoin="round" d="M15.75 6a3.75 3.75 0 1 1-7.5 0 3.75 3.75 0 0 1 7.5 0ZM4.501 20.118a7.5 7.5 0 0 1 14.998 0A17.933 17.933 0 0 1 12 21.75c-2.676 0-5.216-.584-7.499-1.632Z" /></svg>'
                ]
              }),
              jsCreateElement('div', {
                attrs: {
                  style: "font-size: 14px;"
                },
                rawHtml: [
                  '<b>ID:</b> ' + data.id + '<br><b>UUID:</b> ' + data.uuid
                ]
              })
            ]
          }),
          jsCreateElement('div', {
            attrs: {
              style: 'font-size: 14px;text-align: right;'
            },
            rawHtml: [
              '<b>Created at</b> ' + data.created_at.split(".")[0] + '<br><b>Updated at</b> ' + data.updated_at.split(".")[0]
            ]
          })
        ]
      }),
      jsCreateElement('div', {
        attrs: {
          id: 'contactGrid',
        },
        children: [
          jsCreateElement('div', {
            attrs: {
              id: 'contactData',
            },
            children: [
              // Email
              jsCreateElement('div', {
                attrs: {
                  class: 'topBlock itemBlock mt20',
                  style: 'margin-bottom: 20px;'
                },
                children: [
                  jsCreateElement('label', {
                    attrs: {
                      class: 'forinput'
                    },
                    children: ['Email']
                  }),
                  jsCreateElement('input', {
                    attrs: {
                      id: 'contactEmail',
                      value: data.email
                    }
                  })
                ]
              }),
              // Name and Status
              jsCreateElement('div', {
                attrs: {
                  class: 'topBlock itemBlock',
                  style: 'display: grid ; grid-template-columns: 70% 30%; grid-gap: 30px; width: calc(100% - 30px);'
                },
                children: [
                  // Name
                  jsCreateElement('div', {
                    attrs: {
                      class: 'itemBlock'
                    },
                    children: [
                      jsCreateElement('label', {
                        attrs: {
                          class: 'forinput'
                        },
                        children: ['Name']
                      }),
                      jsCreateElement('input', {
                        attrs: {
                          id: 'contactName',
                          value: data.name
                        }
                      })
                    ]
                  }),
                  // Status
                  jsCreateElement('div', {
                    attrs: {
                      class: 'itemBlock'
                    },
                    children: [
                      jsCreateElement('label', {
                        attrs: {
                          class: 'forinput'
                        },
                        children: ['Status']
                      }),
                      jsCreateElement('select', {
                        attrs: {
                          id: 'contactStatus',
                        },
                        children: [
                          jsCreateElement('option', {
                            attrs: {
                              value: 'enabled',
                              selected: data.status == 'enabled' ? 'selected' : false
                            },
                            children: ['Enabled']
                          }),
                          jsCreateElement('option', {
                            attrs: {
                              value: 'disabled',
                              selected: data.status == 'disabled' ? 'selected' : false
                            },
                            children: ['Disabled']
                          })
                        ]
                      })
                    ]
                  }),
                ]
              }),
              // Bounced
              jsCreateElement('div', {
                attrs: {
                  class: "alert-danger bounced" + (data.bounced_at != "" ? '' : ' hideme')
                },
                rawHtml: [
                  "Bounced at<br>" + data.bounced_at
                ]
              }),
              // Complained
              jsCreateElement('div', {
                attrs: {
                  class: "alert-danger complained" + (data.complained_at != "" ? '' : ' hideme')
                },
                rawHtml: [
                  "Complained at<br>" + data.complained_at
                ]
              }),
              // Subscribed
              jsCreateElement('div', {
                attrs: {
                  class: 'itemblock mb40'
                },
                children: [
                  jsCreateElement('label', {
                    attrs: {
                      class: 'inborder'
                    },
                    children: ['Subscribed']
                  }),
                  jsCreateElement('div', {
                    attrs: {
                      class: 'blockBorder'
                    },
                    children: [
                      // Optin text
                      // jsCreateElement('div', {
                      //   children: [
                      //     !data.requires_double_opt_in ? 'This contact does not require double opt-in' : (data.double_opt_in ? 'This contact has opted-in to receive emails' : 'This contact prefers not to receive emails')
                      //   ]
                      // }),
                      jsCreateElement('div', {
                        attrs: {
                          class: 'mb30',
                          style: "display: grid; grid-template-columns: 1fr 1fr; grid-gap: 20px;"
                        },
                        children: [
                          // Force do not require double opt-in - toggle switch from requires_double_opt_in
                          jsCreateElement('div', {
                            attrs: {
                              style: 'display: flex;align-items: center;margin: 10px;'
                            },
                            children: [
                              jsCreateElement('label', {
                                attrs: {
                                  class: 'toggleSwitch compact' + ((!data.requires_double_opt_in && data.double_opt_in) ? ' disabled' : ''),
                                  style: 'margin-right: 10px;'
                                },
                                children: [
                                  jsCreateElement('input', {
                                    attrs: {
                                      id: 'requiresDoubleOptIn',
                                      type: 'checkbox',
                                      checked: data.requires_double_opt_in ? 'checked' : false
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
                                children: [
                                  'Require double opt-in from user'
                                ]
                              })
                            ]
                          }),
                          // Optin toggle
                          jsCreateElement('div', {
                            attrs: {
                              style: 'display: flex;align-items: center;margin: 10px;'
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
                                      id: 'doubleOptIn',
                                      type: 'checkbox',
                                      checked: data.double_opt_in ? 'checked' : false
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
                                children: [
                                  data.double_opt_in ? 'This contact has opted-in to receive emails' : 'This contact has not opted-in to receive emails'
                                ]
                              }),
                            ]
                          }),
                        ]
                      }),
                      // Optin data
                      jsCreateElement('div', {
                        attrs: {
                          style: 'position: relative;margin-top: 30px;',
                          class: 'optin-data mb40' + (data.double_opt_in_data != [] && data.double_opt_in_data.length > 0 ? '' : ' hideme')
                        },
                        children: [
                          jsCreateElement('label', {
                            attrs: {
                              class: 'inborder',
                              style: 'background: transparent;'
                            },
                            children: ['Double opt-in data']
                          }),
                          jsCreateElement('pre', {
                            attrs: {
                              class: 'optin-data-pre',
                              style: 'margin-top: 10px;'
                            },
                            children: [
                              JSON. stringify(data.double_opt_in_data, null, 2)
                            ]
                          })
                        ]
                      }),
                      jsCreateElement('div', {
                        // Subscripted to in first, and pending in second
                        children: [
                          jsCreateElement('div', {
                            attrs: {
                              class: 'subscribed itemBlock' + ((data.requires_double_opt_in && !data.double_opt_in) ? ' mb30' : '')
                            },
                            children: [
                              jsCreateElement('label', {
                                attrs: {
                                  class: 'inborder'
                                },
                                children: ['Subscribed to lists']
                              }),
                              jsCreateElement('button', {
                                attrs: {
                                  style: 'position: absolute; top: -18px; right: 12px; display: flex ; align-items: center; justify-content: center; width: 150px;',
                                  onclick: "seeLists()",
                                  disabled: (data.requires_double_opt_in && !data.double_opt_in) ? true : false
                                },
                                rawHtml: [
                                  '<svg style="height:24px; width: 24px;" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="size-6"><path stroke-linecap="round" stroke-linejoin="round" d="M12 9v6m3-3H9m12 0a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" /></svg><div style="margin-left: 5px;">Add subscription</div>'
                                ]
                              }),
                              jsCreateElement('div', {
                                attrs: {
                                  class: 'blockBorder subscriptionArea'
                                },
                                children: subscriptions
                              })
                            ]
                          }),
                          jsCreateElement('div', {
                            attrs: {
                              class: 'pending itemBlock m20' + ((data.requires_double_opt_in && !data.double_opt_in) ? '' : ' hideme')
                            },
                            children: [
                              jsCreateElement('label', {
                                attrs: {
                                  class: 'inborder'
                                },
                                children: ['Pending opt-in lists']
                              }),
                              jsCreateElement('button', {
                                attrs: {
                                  class: 'addSubscription'  + (data.requires_double_opt_in && data.double_opt_in) ? " hideme" : "",
                                  style: 'position: absolute; top: -18px; right: 12px; display: flex ; align-items: center; justify-content: center; width: 150px;',
                                  onclick: "seeLists()",
                                },
                                rawHtml: [
                                  '<svg style="height:24px; width: 24px;" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="size-6"><path stroke-linecap="round" stroke-linejoin="round" d="M12 9v6m3-3H9m12 0a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" /></svg><div style="margin-left: 5px;">Add pending</div>'
                                ]
                              }),
                              jsCreateElement('div', {
                                attrs: {
                                  class: 'blockBorder subscriptionArea'
                                },
                                children: pendingLists
                              })
                            ]
                          })
                        ]
                      })
                    ]
                  })
                ]
              }),
              // Meta data
              jsCreateElement('div', {
                attrs: {
                  class: 'itemBlock mb40'
                },
                children: [
                  jsCreateElement('label', {
                    attrs: {
                      class: 'inborder'
                    },
                    children: ['Meta data']
                  }),
                  jsCreateElement('button', {
                    attrs: {
                      class: 'addMeta',
                      style: 'position: absolute; top: -18px; right: 12px; display: flex ; align-items: center; justify-content: center;',
                      onclick: "addMeta()"
                    },
                    rawHtml: [
                      '<svg style="height:24px; width: 24px;" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="size-6"><path stroke-linecap="round" stroke-linejoin="round" d="M12 9v6m3-3H9m12 0a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" /></svg><div style="margin-left: 5px;">Add meta</div>'
                    ]
                  }),
                  jsCreateElement('div', {
                    attrs: {
                      id: 'metaArea',
                      class: "blockBorder"
                    },
                    children: metaData
                  })
                ]
              })
            ]
          }),
          jsCreateElement('div', {
            attrs: {
              id: 'contactActivity',
            }
          })
        ]
      })
    ]
  });

  dqs("#contact").append(jsRender(html));

  setTimeout(() => {
    dqs('#contact').classList.add('show');
  }, 10);


  const closeModal = (event) => {
    if (event.type === 'keydown' && event.key !== 'Escape') return;
    if (event.key === 'Escape' || !dqs('#contact').contains(event.target)) {
      dqs('#contact').classList.remove('show');
      document.removeEventListener('keydown', closeModal);
      document.removeEventListener('click', closeModal);
    }
  };

  document.addEventListener('keydown', closeModal);
  document.addEventListener('click', closeModal);

  dqs("#contactEmail").addEventListener('blur', contactUpdate);
  dqs("#contactName").addEventListener('blur', contactUpdate);
  dqs("#contactStatus").addEventListener('change', contactUpdate);
  dqs("#requiresDoubleOptIn").addEventListener('change', contactUpdate);
  dqs("#doubleOptIn").addEventListener('change', contactUpdate);

  labelFloater();
  loadActivity();
}

// -- Meta
function createMetaHTML(key, value) {
  const html = jsCreateElement('div', {
    attrs: {
      class: 'itemBlock metaKeyVal mt20',
      style: 'display: grid; grid-template-columns: 1fr 1fr 40px; grid-gap: 20px;'
    },
    children: [
      jsCreateElement('div', {
        children: [
          jsCreateElement('label', {
            attrs: {
              class: 'forinput'
            },
            children: ['Key']
          }),
          jsCreateElement('input', {
            attrs: {
              onblur: 'contactUpdate()',
              value: key,
              class: 'key'
            }
          }),
        ]
      }),
      jsCreateElement('div', {
        children: [
          jsCreateElement('label', {
            attrs: {
              class: 'forinput'
            },
            children: ['Value']
          }),
          jsCreateElement('input', {
            attrs: {
              onblur: 'contactUpdate()',
              value: value,
              class: 'value'
            }
          }),
        ]
      }),
      jsCreateElement('button', {
        attrs: {
          class: 'delMeta svg16',
          onclick: 'deleteMeta(this)'
        },
        rawHtml: [
          '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="size-6"><path stroke-linecap="round" stroke-linejoin="round" d="m14.74 9-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 0 1-2.244 2.077H8.084a2.25 2.25 0 0 1-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 0 0-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 0 1 3.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 0 0-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 0 0-7.5 0" /></svg>'
        ]
      })
    ]
  });

  return html;
}

function addMeta() {
  dqs("#metaArea").append(jsRender(createMetaHTML('', '')));
}

function deleteMeta(self) {
  self.parentElement.remove();
  contactUpdate();
}

// -- Subscription
function createSubcriptionHTML(listID, type, name, date, ) {
  return jsCreateElement('div', {
    attrs: {
      class: 'subscriptionItem'
    },
    children: [
      jsCreateElement('div', {
        attrs: {
          class: 'center'
        },
        children: [
          jsCreateElement('div', {
            attrs: {
              class: 'subscriptionName'
            },
            children: [name]
          }),
          jsCreateElement('div', {
            attrs: {
              class: 'subscriptionDate'
            },
            children: [date]
          })
        ]
      }),
      jsCreateElement('button', {
        attrs: {
          class: 'svg16',
          onclick: 'removeContactFromList(this, ' + listID + ', \'' + type + '\')'
        },
        rawHtml: [
          '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="size-6"><path stroke-linecap="round" stroke-linejoin="round" d="m14.74 9-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 0 1-2.244 2.077H8.084a2.25 2.25 0 0 1-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 0 0-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 0 1 3.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 0 0-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 0 0-7.5 0" /></svg>'
        ]
      })
    ]
  });
}

function seeLists() {
  // /api/lists/all
  fetch("/api/lists/all", {
    method: "GET"
  })
  .then(manageErrors)
  .then(response => response.json())
  .then(data => {
    buildListHTML(data.data);
  });
}

function buildListHTML(data) {
  let alreadySubscribed = [
    ...globalContact.subscriptions.map(item => item.list_id),
    ...globalContact.pending_lists.map(item => item.id)
  ];

  let sub = []
  for (var i = 0; i < data.length; i++) {
    let item = data[i];
    sub.push(
      jsCreateElement('div', {
        attrs: {
          class: 'listItem'
        },
        children: [
          jsCreateElement('div', {
            attrs: {
              class: (alreadySubscribed.includes(item.id) ? '' : ' hideme'),
              style: 'height: 40px; width: 40px;'
            }
          }),
          jsCreateElement('button', {
            attrs: {
              class: 'svg16' + (alreadySubscribed.includes(item.id) ? ' hideme' : ''),
              onclick: 'addContactToList(' + item.id + ', ' + (item.flows != "0" ? true : false) + ')'
            },
            rawHtml: [
              '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="size-6"><path stroke-linecap="round" stroke-linejoin="round" d="M12 9v6m3-3H9m12 0a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" /></svg>'
            ]
          }),
          jsCreateElement('div', {
            attrs: {
              class: ''
            },
            children: [
              jsCreateElement('div', {
                attrs: {
                  class: 'listName'
                },
                children: [item.name]
              })
            ]
          }),
        ]
      })
    );
  }

  const html = jsCreateElement('div', {
    attrs: {
      style: "width: 300px;"
    },
    children: [
      jsCreateElement('div', {
        attrs: {
          class: 'headingH3 mb20 center',
          style: 'border-bottom: 1px solid var(--colorN30); padding-bottom: 20px;'
        },
        children: ['Add subscriptions to user']
      }),
      jsCreateElement('div', {
        attrs: {
          class: 'listArea'
        },
        children: sub
      })
    ]
  });

  rawModalLoader(jsRender(html));
}

function addContactToList(listID, hasFlow) {
  console.log(listID);
  const html = jsCreateElement('div', {
    attrs: {
      style: 'width: 300px;'
    },
    children: [
      jsCreateElement('div', {
        attrs: {
          class: 'headingH3 mb20 center',
          style: 'border-bottom: 1px solid var(--colorN30); padding-bottom: 20px;'
        },
        children: ['Add to list and start flows']
      }),
      jsCreateElement('p', {
        attrs: {
          class: hasFlow ? '' : 'hideme'
        },
        children: ['Are you sure you want to add this contact to the list? Attached flows will be started.']
      }),
      jsCreateElement('button', {
        attrs: {
          class: 'buttonIcon',
          onclick: `addContactToListDo(${listID})`
        },
        rawHtml: [
          '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="size-6"> <path stroke-linecap="round" stroke-linejoin="round" d="M8.25 6.75h12M8.25 12h12m-12 5.25h12M3.75 6.75h.007v.008H3.75V6.75Zm.375 0a.375.375 0 1 1-.75 0 .375.375 0 0 1 .75 0ZM3.75 12h.007v.008H3.75V12Zm.375 0a.375.375 0 1 1-.75 0 .375.375 0 0 1 .75 0Zm-.375 5.25h.007v.008H3.75v-.008Zm.375 0a.375.375 0 1 1-.75 0 .375.375 0 0 1 .75 0Z" /> </svg><div>Add contact to list</div>']
      })
    ]
  });
  rawModalLoader(jsRender(html));
}

function addContactToListDo(listID) {
  fetch("/api/contacts/list/add", {
    method: "POST",
    body: new URLSearchParams({
      contactID: globalContactID,
      listID: listID,
      listType: (globalContact.requires_double_opt_in && !globalContact.double_opt_in) ? "pending" : "subscribed"
    })
  })
  .then(manageErrors)
  .then(() => {
    dqs(".modalpop").remove();
    // loadContact also syncs the table row's subscribed_lists in place
    loadContact(globalContactID);
  });
}

function removeContactFromList(self, listID, listType) {
  fetch("/api/contacts/list/remove", {
    method: "POST",
    body: new URLSearchParams({
      contactID: globalContactID,
      listID: listID,
      listType: listType
    })
  })
  .then(manageErrors)
  .then(() => {
    // loadContact also syncs the table row's subscribed_lists in place
    loadContact(globalContactID);
  });
}


// -- Update contact
function contactUpdate() {
  let
    email = dqs("#contactEmail").value,
    name = dqs("#contactName").value,
    status = dqs("#contactStatus").value,
    requiresDoubleOptIn = dqs("#requiresDoubleOptIn").checked,
    doubleOptIn = dqs("#doubleOptIn").checked;

  let meta = {};
  dqsA('.metaKeyVal').forEach(item => {
    let key = item.querySelector('.key').value;
    let value = item.querySelector('.value').value;
    meta[key] = value;
  });

  // Skip the API when nothing changed (blur fires even without edits).
  if (
    globalContact &&
    globalContact.email === email &&
    globalContact.name === name &&
    globalContact.status === status &&
    globalContact.requires_double_opt_in === requiresDoubleOptIn &&
    globalContact.double_opt_in === doubleOptIn &&
    JSON.stringify(globalContact.meta || {}) === JSON.stringify(meta)
  ) {
    return;
  }

  fetch("/api/contacts/update", {
    method: "POST",
    body: JSON.stringify({
      contactID: globalContactID,
      email: email,
      name: name,
      status: status,
      double_opt_in: requiresDoubleOptIn,
      opted_in: doubleOptIn,
      meta: JSON.stringify(meta)
    })
  })
  .then(manageErrors)
  .then(() => {
    const optInChanged =
      globalContact.requires_double_opt_in != requiresDoubleOptIn ||
      globalContact.double_opt_in != doubleOptIn;

    // Keep local state and the visible row in sync without refetching all contacts.
    if (globalContact) {
      globalContact.email = email;
      globalContact.name = name;
      globalContact.status = status;
      globalContact.requires_double_opt_in = requiresDoubleOptIn;
      globalContact.double_opt_in = doubleOptIn;
      globalContact.meta = meta;
      globalContact.updated_at = new Date().toISOString().slice(0, 19).replace("T", " ");
    }

    updateContactsTableRow({
      email: email,
      name: name,
      status: status,
      requires_double_opt_in: requiresDoubleOptIn,
      double_opt_in: doubleOptIn,
      country: meta.country || "",
      updated_at: globalContact ? globalContact.updated_at : undefined,
    });

    // Opt-in flips can move list memberships — reload the detail panel only.
    if (optInChanged) {
      loadContact(globalContactID);
    }
  })
}


// -- Activity
function loadActivity() {
  fetch("/api/contacts/get/activity?contactID=" + globalContactID, {
    method: "GET",
    headers: {
      "Content-Type": "application/json",
    }
  })
  .then(manageErrors)
  .then(response => response.json())
  .then(data => {
    buildActivityHTML(data);
  });
}

function buildActivityHTML(data) {

  console.log(data);
  for (var i = 0; i < data.length; i++) {
    let item = data[i];
    console.log(item);
    let
      type = item.type,
      date = item.date.split(".")[0];
    const html = createActivityHTML(type, date, item);
    dqs("#contactActivity").append(jsRender(html));
  }
}


const iconMailPending = '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="size-6"><path stroke-linecap="round" stroke-linejoin="round" d="M21.75 6.75v10.5a2.25 2.25 0 0 1-2.25 2.25h-15a2.25 2.25 0 0 1-2.25-2.25V6.75m19.5 0A2.25 2.25 0 0 0 19.5 4.5h-15a2.25 2.25 0 0 0-2.25 2.25m19.5 0v.243a2.25 2.25 0 0 1-1.07 1.916l-7.5 4.615a2.25 2.25 0 0 1-2.36 0L3.32 8.91a2.25 2.25 0 0 1-1.07-1.916V6.75" /></svg>';
const iconMailSent = '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="size-6"><path stroke-linecap="round" stroke-linejoin="round" d="M9 3.75H6.912a2.25 2.25 0 0 0-2.15 1.588L2.35 13.177a2.25 2.25 0 0 0-.1.661V18a2.25 2.25 0 0 0 2.25 2.25h15A2.25 2.25 0 0 0 21.75 18v-4.162c0-.224-.034-.447-.1-.661L19.24 5.338a2.25 2.25 0 0 0-2.15-1.588H15M2.25 13.5h3.86a2.25 2.25 0 0 1 2.012 1.244l.256.512a2.25 2.25 0 0 0 2.013 1.244h3.218a2.25 2.25 0 0 0 2.013-1.244l.256-.512a2.25 2.25 0 0 1 2.013-1.244h3.859M12 3v8.25m0 0-3-3m3 3 3-3" /></svg>';
const iconMailOpen = '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="size-6"><path stroke-linecap="round" stroke-linejoin="round" d="M21.75 9v.906a2.25 2.25 0 0 1-1.183 1.981l-6.478 3.488M2.25 9v.906a2.25 2.25 0 0 0 1.183 1.981l6.478 3.488m8.839 2.51-4.66-2.51m0 0-1.023-.55a2.25 2.25 0 0 0-2.134 0l-1.022.55m0 0-4.661 2.51m16.5 1.615a2.25 2.25 0 0 1-2.25 2.25h-15a2.25 2.25 0 0 1-2.25-2.25V8.844a2.25 2.25 0 0 1 1.183-1.981l7.5-4.039a2.25 2.25 0 0 1 2.134 0l7.5 4.039a2.25 2.25 0 0 1 1.183 1.98V19.5Z" /></svg>';
const iconMailClicked = '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="size-6"><path stroke-linecap="round" stroke-linejoin="round" d="M15.042 21.672 13.684 16.6m0 0-2.51 2.225.569-9.47 5.227 7.917-3.286-.672ZM12 2.25V4.5m5.834.166-1.591 1.591M20.25 10.5H18M7.757 14.743l-1.59 1.59M6 10.5H3.75m4.007-4.243-1.59-1.59" /></svg>';
const iconMailBounced = '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="size-6"><path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126ZM12 15.75h.007v.008H12v-.008Z" /></svg>';
const iconMailComplain = '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="size-6"><path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m0-10.036A11.959 11.959 0 0 1 3.598 6 11.99 11.99 0 0 0 3 9.75c0 5.592 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.31-.21-2.57-.598-3.75h-.152c-3.196 0-6.1-1.25-8.25-3.286Zm0 13.036h.008v.008H12v-.008Z" /></svg>';

function createActivityHTML(type, date, data) {

  let icon = '';
  switch (type) {
    case 'pending_email':
      icon = iconMailPending;
      break;
    case 'mail_sent':
      icon = iconMailSent;
      break;
    case 'email_open':
      icon = iconMailOpen;
      break;
    case 'email_click':
      icon = iconMailClicked;
      break;
    case 'email_bounce':
      icon = iconMailBounced;
      break;
    case 'email_complaint':
      icon = iconMailComplain;
      break;
  }

  let heading = '';
  switch (type) {
    case 'pending_email':
      if (data.sent_at != "") {
        heading = 'Email sent';
      }
      else if (data.scheduled_for != "") {
        heading = 'Email scheduled';
      }
      else {
        heading = 'Pending email';
      }
      break;
    case 'mail_sent':
      heading = 'Email sent';
      break;
    case 'email_open':
      heading = 'Email opened';
      break;
    case 'email_click':
      heading = 'Email clicked';
      break;
    case 'email_bounce':
      heading = 'Email bounced';
      break;
    case 'email_complaint':
      heading = 'Email complaint';
      break;
  }

  let text = '';
  switch (type) {
    case 'pending_email':
      text = '<b>Flow:</b> \'' + data.flow_name + '\'<br><b>Subject:</b> \'' + data.subject + '\'';
      if (data.sent_at != "") {
        text += '<br><b>Sent at:</b> ' + data.sent_at.split(".")[0];
      }
      else if (data.scheduled_for != "") {
        text += '<br><b>Scheduled for:</b> ' + data.scheduled_for.split(".")[0];
      }
      else {
        text += '<br><b>Trigger:</b> ' + data.trigger_type;
      }
      break;
    case 'mail_sent':
      break;
    case 'email_open':
      text = '<b>Subject:</b> ' + data.subject + '<br><b>Opened at:</b> ' + data.date.split(".")[0];
      break;
    case 'email_click':
      text = '<b>Subject:</b> ' + data.subject + '<br><b>Clicked at:</b> ' + data.date.split(".")[0] + '<br><b>URL:</b> ' + data.link_url;
      break;
    case 'email_bounce':
      text = '<b>Bounced at:</b> ' + data.date.split(".")[0] + '<br><b>Reason:</b> ' + data.bounced_feedback + " - " + data.bounce_subtype + " (" + data.diagnostic_code + ")";
      break;
    case 'email_complaint':
      text = '<b>Complained at:</b> ' + data.date.split(".")[0] + '<br><b>Feedback type:</b> ' + data.complaint_feedback;
      break;
  }


  const html = jsCreateElement('div', {
    attrs: {
      class: 'activityItem',
      onclick: (data.mail_id) ? 'loadMail(' + data.mail_id + ')' : '',
      style: (data.mail_id) ? 'cursor: pointer;' : ''
    },
    children: [
      jsCreateElement('div', {
        children: [
          jsCreateElement('div', {
            attrs: {
              class: 'activityType'
            },
            children: [heading]
          }),
          jsCreateElement('div', {
            attrs: {
              class: 'activityDate'
            },
            children: [date]
          }),
          jsCreateElement('div', {
            attrs: {
              class: 'activityData'
            },
            rawHtml: [
              text
            ]
          })
        ],
      }),
      jsCreateElement('div', {
        attrs: {
          class: "svg30",
          style: "display: flex ; align-items: center;"
        },
        rawHtml: [
          icon
        ]
      })
    ]
  });
  return html;
}

