window.addEventListener("DOMContentLoaded", (event) => {
  function checkUrlPath() {
    const path = window.location.pathname;

    if (window.location.href.includes("#")) {
      return;
    }

    switch (path) {
      case '/contacts':
        tableContacts();
        break;
      case '/mails':
        tableMails();
        break;
      case '/lists':
        tableLists();
        break;
      case '/flows':
        tableFlows();
        break;
      case '/maillog':
        tableMaillog();
        break;
      case '/settings':
        buildSettingsHtml();
        break;
      // default:
      //   dqs("#heading").innerText = "Nimletter, drip it!";
      //   dqs("#work").innerHTML = '<img src="/assets/images/nimletter.png">';
    }
  }

  window.addEventListener("popstate", checkUrlPath);

  checkUrlPath();
});


function addNewButton(eleID, onclick, text) {
  return `
    <button onclick="${onclick}" style="display: flex ; align-items: center;width: 200px; justify-content: center;">
      <svg style="height:24px; width: 24px;" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="size-6"><path stroke-linecap="round" stroke-linejoin="round" d="M12 9v6m3-3H9m12 0a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" /></svg>
      <div style="margin-left: 5px;">${text}</div>
    </button>
    <div id="${eleID}"></div>
  `;
}

function addNewButtonClean(onclick, text) {
  return `
    <button onclick="${onclick}" style="display: flex ; align-items: center;width: 200px; justify-content: center;">
      <svg style="height:24px; width: 24px;" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="size-6"><path stroke-linecap="round" stroke-linejoin="round" d="M12 9v6m3-3H9m12 0a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" /></svg>
      <div style="margin-left: 5px;">${text}</div>
    </button>
  `;
}


/*

  Contacts

*/
let objTableContacts;
function tableContacts() {
  dqs("#heading").innerText = "Contacts";
  dqs("#infotext").innerHTML = 'These are all the contacts in the system. A contact can just "be here" without subscribing to any list. A contact can also be subscribe to one or more lists. You can manually do these actions. We keep contacts here even when email bounces or complaints to ensure we don\'t resend emails to them.';
  dqs("#work").innerHTML = addNewButton("contacts", "addContact()", "Add contact");

  objTableContacts = new Tabulator("#contacts", {
    height:"70vh",
    layout:"fitColumns",
    ajaxURL:"/api/contacts/all",
    paginationSize:15000,
    progressiveLoad:"load",
    initialSort:[
      {column:"status", dir:"desc"},
      {column:"created_at", dir:"desc"},
    ],
    rowFormatter:function(row){
      var data = row.getData();

      // If bounced_at then extreme red, if complained_at then extreme orange
      if(data.bounced_at){
        row.getElement().style.backgroundColor = "#ff5959";
      } else if(data.complained_at){
        row.getElement().style.backgroundColor = "#FFA500";
      } else if(data.status == 'disabled'){
        row.getElement().style.backgroundColor = "#c2c2c2";
      }

    },
    columns:[
      {formatter:"rowSelection", titleFormatter:"rowSelection", titleFormatterParams:{
        rowRange:"active"
      }, hozAlign:"center", headerSort:false},
      {title:"ID", field:"id", width:50, headerFilter:true},
      {title:"Email", field:"email", width:250, headerFilter:true, cssClass:"semibold"},
      {title:"Name", field:"name", width:200, headerFilter:true},
      {title:"Status", field:"status", width:100, headerFilter:true},
      {title:"Requires Double Opt-In", field:"requires_double_opt_in", hozAlign:"center", width: 80, headerFilter:true, formatter:"toggle", formatterParams:{
        size:16,
        onValue:"on",
        offValue:"off",
        onTruthy:true,
        onColor:"var(--colorG200)",
        offColor:"var(--colorN80)",
        clickable:false,
      }},
      {title:"Double Opt-In", field:"double_opt_in", hozAlign:"center", width: 80, headerFilter:true, formatter:"toggle", formatterParams:{
        size:16,
        onValue:"on",
        offValue:"off",
        onTruthy:true,
        onColor:"var(--colorG200)",
        offColor:"var(--colorN80)",
        clickable:false,
      }},

      {title:"Country", field:"country", hozAlign:"left", width: 140, headerFilter:true},

      // Lists
      {title:"Lists", field:"subscribed_lists", hozAlign:"left", width: 300, headerFilter:true, formatter:function(cell, formatterParams, onRendered){
      if (cell.getValue() == "") {
        return "";
      }

      let lists = cell.getValue().split(", ");
      let html = "";
      lists.forEach(list => {
        html += `<div style="font-size: 10px; border: 1px solid var(--colorN100); border-radius: 10px; padding: 0px 6px; background-color: var(--colorN20); margin-right: 5px;white-space: nowrap; overflow: hidden; text-overflow: ellipsis;" title="${list}">${list}</div>`;
      });
      return '<div style="display: flex">' + html + '</div>';
      }},

      // {title:"Bad opening rate", field:"bad_opening_rate", hozAlign:"center", width: 140, headerFilter:true, formatter:function(cell, formatterParams, onRendered){
      //   let data = cell.getRow().getData();
      //   if(data.emails_count_sent >= 2 && data.emails_count_open <= 0){
      //     return '<div style="color: red; font-weight: 500;">Yes</div>';
      //   } else {
      //     return '<div style="color: green; font-weight: 500;">No</div>';
      //   }
      // }},

      {title:"Opening Rate", field:"opening_rate", hozAlign:"center", width: 140, headerFilter:true, formatter:function(cell, formatterParams, onRendered){
      let
        rowData = cell.getRow().getData(),
        sent = rowData.emails_count_sent,
        open = rowData.emails_count_open;

      return sent > 0 ? Math.round((open / sent) * 100) + "%" : "0%";
      }
      },
      {title:"Emails Open", field:"emails_count_open", hozAlign:"center", width: 140, headerFilter:true},
      {title:"Emails Clicks", field:"emails_count_clicks", hozAlign:"center", width: 140, headerFilter:true},
      {title:"Emails Sent", field:"emails_count_sent", hozAlign:"center", width: 140, headerFilter:true},
      {title:"Emails Pending", field:"emails_count_pending", hozAlign:"center", width: 140, headerFilter:true},

      {title:"Has Unsubscribed", field:"has_unsubscribed", hozAlign:"center", width: 140, headerFilter:true, formatter:function(cell, formatterParams, onRendered){
        return cell.getValue() ? "Yes" : "No";
      }},
      {title:"Unsubscribed At", field:"unsubscribed_at", hozAlign:"center", sorter:"datetime", sorterParams:{ format:"yyyy-MM-dd HH:mm:ss"}, width: 140, headerFilter:true},
      {title:"Unscribed From Lists", field:"unscribed_from_lists", hozAlign:"left", width: 140, headerFilter:true},

      {title:"Bounced At", field:"bounced_at", hozAlign:"center", sorter:"datetime", sorterParams:{ format:"yyyy-MM-dd HH:mm:ss"}, width: 140, headerFilter:true},
      {title:"Complained At", field:"complained_at", hozAlign:"center", sorter:"datetime", sorterParams:{ format:"yyyy-MM-dd HH:mm:ss"}, width: 140, headerFilter:true},
      {title:"Created At", field:"created_at", hozAlign:"center", sorter:"datetime", sorterParams:{ format:"yyyy-MM-dd HH:mm:ss"}, width: 160, headerFilter:true},
      {title:"Updated At", field:"updated_at", hozAlign:"center", sorter:"datetime", sorterParams:{ format:"yyyy-MM-dd HH:mm:ss"}, width: 160, headerFilter:true},
    ],
    });

  objTableContacts.on("rowClick", function(e, row){
    loadContact(row.getData().id);
  });

  // Add CSV download context menu
  addTabulatorContextMenu(objTableContacts, "contacts.csv");

}


/*

  Mails

*/
var objTableMails;

function toggleArchivedMails() {
  let filters = objTableMails.getFilters();
  for(let i = 0; i < filters.length; i++){
    if(filters[i].field == "category"){
      if(filters[i].value == "archived" && filters[i].type == "="){
        objTableMails.setFilter("category", "!=", "archived");
      } else {
        objTableMails.setFilter("category", "=", "archived");
      }
    }
  }
}
function tableMails() {
  dqs("#heading").innerText = "Mails";
  dqs("#infotext").innerHTML = 'These are all the mails in the system. A mail can be a single email sent as a one-time (e.g. "Welcome to Nimletter!"), or a flow (e.g. "Nimletter tips").';

  dqs("#work").innerHTML = `<div style="display: grid; grid-template-columns: repeat(auto-fill, minmax(max(200px, 100px), 1fr)); grid-gap: 30px;">
      ${addNewButtonClean("addMail()", "Add mail")}
      ${addNewButtonClean("toggleArchivedMails()", "Show archived")}
    </div><div id="mails"></div>`;

  objTableMails = new Tabulator("#mails", {
    height:"70vh",
    layout:"fitColumns",
    ajaxURL:"/api/mails/all",
    progressiveLoad:"load",
    paginationSize: 1000,
    initialSort:[
      {column:"name", dir:"asc"},
      {column:"category", dir:"asc"},
    ],
    initialFilter:[
      {field:"category", type:"!=", value:"archived"}
    ],
    // rowHeight:50,
    columns:[
      {title:"ID", field:"id", vertAlign: "middle", width:60, headerFilter:true},
      {title:"Category", field:"category", vertAlign: "middle", width:200, cssClass:"semibold", headerFilter:true, formatter:function(cell, formatterParams, onRendered){
        const category = cell.getValue();
        const emojiMap = {
          'template': '📋',
          'newsletter': '📰',
          'drip': '💧',
          'campaign': '🎯',
          'singleshot': '📤',
          'event': '📅',
          'flow': '🔄'
        };
        const emoji = emojiMap[category] || '📧';
        return `<span style="font-size: 16px; margin-right: 8px;">${emoji}</span>${category}`;
      }},
      {title:"Identifier", field:"identifier", vertAlign: "middle", width:200, headerFilter:true},
      {title:"Name", field:"name", vertAlign: "middle", minWidth:200, headerFilter:true},
      {title:"Subject", field:"subject", vertAlign: "middle", minWidth:250, headerFilter:true},
      {title:"Tags", field:"tags", vertAlign: "middle", width:200, headerFilter:true, formatter:function(cell, formatterParams, onRendered){
        if (cell.getValue() == "") {
          return "";
        }
        let tags = cell.getValue();
        let html = "";
        tags.forEach(list => {
          html += `<div style="font-size: 12px; border: 1px solid var(--colorN100); border-radius: 10px; padding: 0px 6px; background-color: var(--colorN20); margin-right: 5px;">${list}</div>`;
        });
        return '<div style="display: flex">' + html + '</div>';
      }},
      {title:"Sent count", field:"sent_count", vertAlign: "middle", width:120, headerFilter:true},
      {title:"Pending count", field:"pending_count", vertAlign: "middle", width:120, headerFilter:true},
      {title:"Opened count", field:"opened_count", vertAlign: "middle", width:120, headerFilter:true},
      {title:"Clicked count", field:"clicked_count", vertAlign: "middle", width:120, headerFilter:true},
      {title:"Created At", field:"created_at", vertAlign: "middle", hozAlign:"center", sorter:"datetime", sorterParams:{ format:"yyyy-MM-dd HH:mm:ss"}, width: 160, headerFilter:true},
      {title:"Updated At", field:"updated_at", vertAlign: "middle", hozAlign:"center", sorter:"datetime", sorterParams:{ format:"yyyy-MM-dd HH:mm:ss"}, width: 160, headerFilter:true},
    ],
  });

  objTableMails.on("rowClick", function(e, row){
    // loadMail(row.getData().id);
    if (e.ctrlKey) {
      window.open("/mails?viewMail=" + row.getData().id, "_blank");
    } else {
      window.location.href = "/mails?viewMail=" + row.getData().id;
    }
  });

  // Query parameter is viewMail=<id> then open the mail
  if(window.location.search.includes("viewMail=")){
    let id = window.location.search.split("viewMail=")[1];
    loadMail(id);
  }

  // Add CSV download context menu
  addTabulatorContextMenu(objTableMails, "mails.csv");
}


/*

  Lists

*/
let objTableLists;
function tableLists() {
  dqs("#heading").innerText = "Lists";
  dqs("#infotext").innerHTML = 'A list is where people subscribe - without lists, then people cannot subscribe. Imagine a list being a newsletter for Nim-News - something with either ad-hoc or planned emails. Then you can send direct mails to this list (e.g. "new Nim release!!"), or you can attach multiple flows (e.g. "Nim for starters" and "Nim installation guide").';
  dqs("#work").innerHTML = addNewButton("lists", "addList()", "Add list");

  objTableLists = new Tabulator("#lists", {
    height:"70vh",
    layout:"fitColumns",
    ajaxURL:"/api/lists/all",
    progressiveLoad:"load",
    paginationSize: 1000,
    // rowHeight:50,
    columns:[
      {title:"ID", field:"id", width:60, headerFilter:true},
      // {title:"UUID", field:"uuid", width:200},
      {title:"Name", field:"name", vertAlign: "middle", width:300, headerFilter:true, cssClass:"semibold"},
      {title:"Description", field:"description", vertAlign: "middle", width:250, headerFilter:true},
      // {title:"Flow ID", field:"flow_id", vertAlign: "middle", width:200},
      {title:"Identifier", field:"identifier", vertAlign: "middle", width:200, headerFilter:true},
      {title:"Contacts", field:"user_count", vertAlign: "middle", width:200, headerFilter:true, formatter:function(cell, formatterParams, onRendered){
      return cell.getValue() + ' subscribers';
      }},
      {title:"Flow Count", field:"flows", vertAlign: "middle", width:200, headerFilter:true},
      {title:"Created At", field:"created_at", vertAlign: "middle", hozAlign:"center", sorter:"datetime", sorterParams:{ format:"yyyy-MM-dd HH:mm:ss"}, width: 200, headerFilter:true},
      {title:"Updated At", field:"updated_at", vertAlign: "middle", hozAlign:"center", sorter:"datetime", sorterParams:{ format:"yyyy-MM-dd HH:mm:ss"}, width: 200, headerFilter:true},
      {title:"Delete", field:"delete", cssClass:"slimpadding", formatter:function(cell, formatterParams, onRendered){
      return '<button onclick="removeList(' + cell.getRow().getData().id + ')">Delete</button>';
      }},
    ],
  });

  objTableLists.on("cellClick", function(e, cell){
    if (cell.getField() == "delete") {
      return;
    }
    openList(cell.getRow().getData().id);
  });

  // Add CSV download context menu
  addTabulatorContextMenu(objTableLists, "lists.csv");
}


/*

  Flows

*/
let objTableFlows;
function tableFlows() {
  dqs("#heading").innerText = "Flows";
  dqs("#infotext").innerHTML = 'A flow is a sequence of emails that are sent to a list. A simple flow could be 5 emails, with a delay of 1 day between each email (e.g. "Welcome to Nimletter!", "How to use Nimletter", "Nimletter tips", "Nimletter FAQ", "Nimletter support"). A more complex flow could be 10 emails, with different delays between each email, and some might require the user to click on a link to continue.';
  dqs("#work").innerHTML = addNewButton("flows", "addFlow()", "Add flow");

  objTableFlows = new Tabulator("#flows", {
    height:"70vh",
    layout:"fitColumns",
    ajaxURL:"/api/flows/all",
    progressiveLoad:"load",
    paginationSize: 1000,
    columns:[
      {title:"ID", field:"id", width:60, headerFilter:true},
      // {title:"UUID", field:"uuid", width:200},
      {title:"Name", field:"name", width:300, headerFilter:true, cssClass:"semibold"},
      {title:"Description", field:"description", width:250, headerFilter:true},
      {title:"Opening Rate", field:"opening_rate", width:150, headerFilter:true},
      {title:"Pending Count", field:"pending_count", width:150, headerFilter:true},
      {title:"Sent Count", field:"sent_count", width:150, headerFilter:true},
      {title:"Created At", field:"created_at", hozAlign:"center", sorter:"datetime", sorterParams:{ format:"yyyy-MM-dd HH:mm:ss"}, width: 200, headerFilter:true},
      {title:"Updated At", field:"updated_at", hozAlign:"center", sorter:"datetime", sorterParams:{ format:"yyyy-MM-dd HH:mm:ss"}, width: 200, headerFilter:true},
      {title:"Delete", field:"delete", cssClass:"slimpadding", formatter:function(cell, formatterParams, onRendered){
      return '<button onclick="removeFlow(' + cell.getRow().getData().id + ')">Delete</button>';
      }},
    ],
  });

  objTableFlows.on("cellClick", function(e, cell){
    if (cell.getField() == "delete") {
      return;
    }
    openFlow(cell.getRow().getData().id, cell.getRow().getData().name);
  });

  // Add CSV download context menu
  addTabulatorContextMenu(objTableFlows, "flows.csv");
}


/*

  Flowsteps

*/
function tableFlowsteps(flowID) {
  dqs("#work").innerHTML = `
    <div id="flowsteps"></div>
  `;

  var objTableFlowsteps = new Tabulator("#flowsteps", {
    height:"70vh",
    layout:"fitColumns",
    ajaxURL:"/api/flowsteps/all?flowID=" + flowID,
    progressiveLoad:"load",
    paginationSize: 1000,
    columns:[
      {title:"ID", field:"id", width:100},
      {title:"Flow ID", field:"flow_id", width:200},
      {title:"Mail ID", field:"mail_id", width:200},
      {title:"Step Number", field:"step_number", width:150},
      {title:"Delay Minutes", field:"delay_minutes", width:150},
      {title:"Subject", field:"subject", width:250},
      {title:"Created At", field:"created_at", hozAlign:"center", sorter:"datetime", sorterParams:{ format:"yyyy-MM-dd HH:mm:ss"}, width: 200},
      {title:"Updated At", field:"updated_at", hozAlign:"center", sorter:"datetime", sorterParams:{ format:"yyyy-MM-dd HH:mm:ss"}, width: 200},
    ],
  });

  // Add CSV download context menu
  addTabulatorContextMenu(objTableFlowsteps, "flowsteps.csv");
}



/*

  Maillog

*/
function addNewButtonLog(eleID, onclick, text) {
  return `
    <button onclick="${onclick}" style="display: flex ; align-items: center;width: 200px; justify-content: center;">
      <svg style="height:24px; width: 24px;" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="size-6"><path stroke-linecap="round" stroke-linejoin="round" d="M12 9v6m3-3H9m12 0a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" /></svg>
      <div style="margin-left: 5px;">${text}</div>
    </button>
  `;
}

let objTableMaillog;
function tableMaillog() {
  dqs("#heading").innerText = "Maillog";
  dqs("#infotext").innerHTML = 'The maillog is a log of all the emails that have been sent. It is useful to see the status of an email, and to see when it was sent.';
  dqs("#work").innerHTML = `<div style="display: grid; grid-template-columns: repeat(auto-fill, minmax(max(200px, 100px), 1fr)); grid-gap: 30px;">
      ${addNewButtonLog("loadPending", "mailLogLoad('pending')", "Load pending")}
      ${addNewButtonLog("loadAll", "mailLogLoad('all')", "Load all mails")}
      ${addNewButtonLog("loadSent", "mailLogLoad('sent')", "Load sent")}
    </div><div id="maillog"></div>`;

  objTableMaillog = new Tabulator("#maillog", {
    height:"70vh",
    layout:"fitColumns",
    ajaxURL:"/api/mails/log?status=pending",
    progressiveLoad:"scroll",
    paginationSize:5000,
    initialSort:[
      {column:"sent_at", dir:"desc"}
    ],
    rowFormatter:function(row){
      var data = row.getData();

      if(data.status == "pending"){
        row.getElement().style.backgroundColor = "#fff9bf8f";
      } else if(data.status == "sent"){
        row.getElement().style.backgroundColor = "#b3ffb8";
      } else if(data.status == "inprogress"){
        row.getElement().style.backgroundColor = "#b3e4ff";
      } else if(data.status == "bounced"){
        row.getElement().style.backgroundColor = "#ff5959";
      } else if(data.status == "complained"){
        row.getElement().style.backgroundColor = "#FFA500";
      } else if(data.status == "cancelled"){
        row.getElement().style.backgroundColor = "#b1b1b1";
      }
    },
    columns:[
      {title:"ID", field:"id", width:80},
      {title:"Status", field:"status", width:100, headerFilter:true},
      {title:"Created", field:"created_at", hozAlign:"center", sorter:"datetime", sorterParams:{ format:"yyyy-MM-dd HH:mm:ss"}, width: 140, headerFilter:true},
      {title:"Scheduled", field:"scheduled_for", width:140, sorter:"datetime", sorterParams:{ format:"yyyy-MM-dd HH:mm:ss"}, headerFilter:true},
      {title:"Sent At", field:"sent_at", width:140, sorter:"datetime", sorterParams:{ format:"yyyy-MM-dd HH:mm:ss"}, headerFilter:true},
      {title:"Opened", field:"opened", width:90, headerFilter:true},
      {title:"Clicked", field:"clicked", width:90, headerFilter:true},
      {title:"User Email", field:"user_email", minWidth:200, headerFilter:true},
      {title:"Country", field:"country", width:160, headerFilter:true},
      {title:"List Name", field:"list_name", minWidth:160, headerFilter:true},
      {title:"Flow Name", field:"flow_name", minWidth:160, headerFilter:true},
      {title:"Flow Step Name", field:"flow_step_name", width:160, headerFilter:true},
    ],
  });

  // Add CSV download context menu
  addTabulatorContextMenu(objTableMaillog, "maillog.csv");
}

function mailLogLoad(status) {
  objTableMaillog.setData("/api/mails/log?status=" + status);

  if (status == "pending") {
    objTableMaillog.setSort([
      {column:"scheduled_at", dir:"desc"}, //sort by this first
    ]);
  }
  else if(status == "sent") {
    objTableMaillog.setSort([
      {column:"sent_at", dir:"desc"}, //sort by this first
    ]);
  }
  else {
    objTableMaillog.setSort([
      {column:"created_at", dir:"desc"}, //sort by this first
  ]);
  }
}