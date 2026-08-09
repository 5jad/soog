global.document = {
  getElementById: (id) => {
    if (id === 'content') return contentMock;
    return { textContent: '' };
  }
};
const contentMock = { innerHTML: 'SKELETONS' };
global.API = {
  get: async (url) => {
    if(url.includes('stats')) return {"stats":{"orders_today":0,"new_orders":0,"sales_today":0,"gross_today":0,"commission_today":"0.0","active_stores":4,"new_customers":0,"total_customers":7,"n":1,"queue":{"ads":0,"docs":1,"cash":0}},"recent":[]};
    if(url.includes('sales')) return {"days":[{"date":"2026-08-06","total":122000}],"categories":[],"top_stores":[]};
    if(url.includes('settings')) return {"settings":{"daily_goal":"5000000"}};
  }
};
global.router = { go: () => {} };
global.fmt = (n) => n;
global.moneySpan = (n) => n;
global.statusChip = (n) => n;
global.timeAgo = (n) => n;
global.esc = (n) => n;
global.renderStores = () => {};
global.renderOrders = () => {};
global.renderAds = () => {};
global.renderCash = () => {};
global.renderUsers = () => {};
global.renderGeo = () => {};
global.renderNotify = () => {};
global.renderSettings = () => {};
global.renderAudit = () => {};

const fs = require('fs');
const code = fs.readFileSync('admin-dashboard/js/views/overview.js', 'utf8');
eval(code);

renderOverview().then(() => {
  console.log("SUCCESS");
}).catch(e => {
  console.error("Error in renderOverview:", e);
});
