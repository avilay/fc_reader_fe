var showingItemId = 0

function showFullItem(itemId) {
  closeFullItem(showingItemId)
  document.getElementById("item"+itemId+"_blurb").style.display = "none"
  divid = document.getElementById("item"+itemId)
  divid.style.display = "block"
  divid.scrollIntoView(true)
  showingItemId = itemId
  readItem(itemId)
}

function closeFullItem(itemId) {
  if(showingFullItem = document.getElementById("item"+showingItemId)) {
    showingFullItem.style.display = "none"
  }
  if(showingItemBlurb = document.getElementById("item"+showingItemId+"_blurb")) {
    showingItemBlurb.style.display = "block"
  }
  showingItemId = 0
}

function highlightItem(itemId) {
  document.getElementById("item" + itemId + "_blurb").style.background = "#EDE8E8"
}

function normalizeItem(itemId) {
  document.getElementById("item" + itemId + "_blurb").style.background = ""  
}

function beginEditFeeds() {
  document.getElementById("myFeedsEditable").style.display = "block"
  document.getElementById("myFeeds").style.display = "none"
}

function endEditFeeds() {
  document.getElementById("myFeedsEditable").style.display = "none"
  document.getElementById("myFeeds").style.display = "block" 
}

function addFeeds() {
  url = '/feeds/add_form'
  window.open(url, 'Add Feeds', 'location=1,links=0,scrollbars=0,toolbar=0,width=500,height=620')
}

function removeFeed(feedId) {
  var xmlhttp = new XMLHttpRequest();
  xmlhttp.open("POST", "/feeds/remove", true);
  xmlhttp.setRequestHeader("Content-type","application/x-www-form-urlencoded");
  xmlhttp.send("feed_id="+feedId);
  xmlhttp.onreadystatechange=function() {
    if(xmlhttp.status!=200) {
      document.getElementById("page_errors").innerHTML="<p>Feed could not be deleted!</p>"
    } 
    else {
      feedNode = document.getElementById("feed"+feedId)
      feedNode.parentNode.removeChild(feedNode)
      feedLinkNode = document.getElementById("feed"+feedId+"_link")
      feedLinkNode.parentNode.removeChild(feedLinkNode)
    }   
  }
}

function readItem(itemId) {
  var xmlhttp = new XMLHttpRequest();
  xmlhttp.open("GET", "/items/" + itemId + "/read", true);
  xmlhttp.send();  
}
