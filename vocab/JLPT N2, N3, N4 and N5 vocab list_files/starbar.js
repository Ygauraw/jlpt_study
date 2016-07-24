var starPath = "/site_base/starbar/";
var greyStarPath = starPath + "greystar.gif";
var starPath = starPath + "star.gif";

var lastClickedStarNumber;
var lastHoveredStarNumber;

function mouseOver(starObject){
	starObject.src = starPath;
	if (starObject.id=="star1") lastHoveredStarNumber=1;
	if (starObject.id=="star2") lastHoveredStarNumber=2;
	if (starObject.id=="star3") lastHoveredStarNumber=3;
	if (starObject.id=="star4") lastHoveredStarNumber=4;
	if (starObject.id=="star5") lastHoveredStarNumber=5;
	highlightStars(lastHoveredStarNumber);
	
}

function mouseOut(starObject){
	starObject.src = greyStarPath;
	highlightStars(lastClickedStarNumber);
}

function mouseClick(starObject){

	if (starObject.id=="star1link") lastClickedStarNumber=1;
	if (starObject.id=="star2link") lastClickedStarNumber=2;
	if (starObject.id=="star3link") lastClickedStarNumber=3;
	if (starObject.id=="star4link") lastClickedStarNumber=4;
	if (starObject.id=="star5link") lastClickedStarNumber=5;
	
	getElement('numStars').value=lastClickedStarNumber;
	
	toggleLayer('feedbackpanel');
	highlightStars(lastClickedStarNumber);
	
	if (getElement('feedbackText').display=='block'){
		getElement('feedbackText').focus();
	}
	
}

function highlightStars(numberOfStars){

getElement('star1').src = greyStarPath;
getElement('star2').src = greyStarPath;
getElement('star3').src = greyStarPath;
getElement('star4').src = greyStarPath;
getElement('star5').src = greyStarPath;
	
if (numberOfStars >= 1) getElement('star1').src=starPath;
if (numberOfStars >= 2) getElement('star2').src=starPath;
if (numberOfStars >= 3) getElement('star3').src=starPath;
if (numberOfStars >= 4) getElement('star4').src=starPath;
if (numberOfStars >= 5) getElement('star5').src=starPath;

}

function getElement (elementName){
  if( document.getElementById ) // this is the way the standards work
    elem = document.getElementById( elementName );
  else if( document.all ) // this is the way old msie versions work
      elem = document.all[elementName];
  else if( document.layers ) // this is the way nn4 works
    elem = document.layers[elementName]; 
  return elem;
}

function toggleLayer( whichLayer )
{
  var elem, vis;
  if( document.getElementById ) // this is the way the standards work
    elem = document.getElementById( whichLayer );
  else if( document.all ) // this is the way old msie versions work
      elem = document.all[whichLayer];
  else if( document.layers ) // this is the way nn4 works
    elem = document.layers[whichLayer];
  vis = elem.style;
  // if the style.display value is blank we try to figure it out here
  if(vis.display==''&&elem.offsetWidth!=undefined&&elem.offsetHeight!=undefined)
    vis.display = (elem.offsetWidth!=0&&elem.offsetHeight!=0)?'block':'none';
  vis.display = (vis.display==''||vis.display=='block')?'none':'block';
}
