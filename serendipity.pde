//Copyright (C) 2013 Anton Pirogov
//Licensed under the MIT License

//To track resizes
int oldWidth = 800;
int oldHeight = 800;

//Global game object
Game game;

//TODO:
//change color selection routine? (show colors around each player, gray out if selected)
//make work with processing.js
//refactor
  
void setup() {
  size(oldWidth, oldHeight);
  textAlign(CENTER);

  /* make resizable */
  if (frame != null) {
    frame.setResizable(true); 
  }
  
  game = new Game();
  game.draw();
}
void draw() {
  /* resize if needed */
  if (width != oldWidth || height != oldHeight) {
    game.calculateSizes();
    oldWidth=width;
    oldHeight=height;
    game.draw();
  }
}

//Input handlers
void mouseClicked() {
  game.click(mouseX, mouseY, mouseButton);
}

void mouseWheel(MouseEvent event) {
  float e = event.getAmount(); //Wheel direction/strength
  int dir = int(e/abs(e)); //normalize
  game.wheel(mouseX,mouseY,dir);
}

void keyPressed() {
  if (keyCode==BACKSPACE) { //"back" key
    if (game.state >= 3) { //A game is running -> reset
      game = new Game();
    } else
      game.state--;
    if (game.state<0)
      game.state = 0;
  } else if (key == 'd') { //toggle view
    game.darkenTiles = !game.darkenTiles;
  }
  game.draw();
}

/* CLASSES */

class Game {
  String gametitle = "Serendipity";
  
  Board gameboard; //Contains all tiles
  ArrayList<Player> players; //Player array
  int currentPlayer = 0; //Index of current player
 
  SettingsInterface menu; //Responsible for initial settings

  int state = 0; //State of the game instance
  
  //Memorize clicked tiles in different contexts
  Tile selectedTile = null;
  Tile jokerSwap = null;
  
  boolean darkenTiles = false; //view toggle
  
  //Used colors for text
  color goodColor = color(0,128,0);
  color badColor = color(128,0,0);
  color neutralColor = color(128,128,0);
  
  //Init
  Game() {
    gameboard = new Board();
    players = new ArrayList<Player>();
    menu = new SettingsInterface(this);
    
    players.add(new Player(false));
    players.add(new Player(false));
    allocateColors();
  }
  
  //on screen resize
  void calculateSizes() {
    menu.calculateSizes();
    gameboard.calculateSizes(); 
  }
  
  //returns an array of open tiles owned by a player (his colors)
  ArrayList<Tile> getOpenPlayerTiles(Player p) {
    ArrayList<Tile> ret = new ArrayList<Tile>();
    for (int i=0, sub=-5; i<=10; i++, sub++) {
      int max = 11-abs(sub);
      for (int j=0; j<max; j++) {
        Tile t = gameboard.tiles.get(i).get(j);
        if (p.colors.contains(t.clr) && t.open) {
          ret.add(t);
        }
      }
    }
    return ret;
  }
  
  //returns an array of all neighbor tiles of a tile, clockwise
  //for missing neighbors (at corners) null elements
  ArrayList<Tile> getNeighborTiles(Tile src) {
    ArrayList<Tile> ret = new ArrayList<Tile>();
    int[] pos = src.getTileCoords();
    int y = pos[0], x = pos[1], x1 = x, x2 = 0;
    Tile t = null;
    
    //Calculate index offsets
    if (y==5) {
      x2 = --x1;
    } else if (y<5) {
      x2 = x1--;
    } else if (y>5) {
      x2 = x1-1;
    }
    
    //Add Clockwise
    t = gameboard.getTile(y-1,x1+1);
    ret.add(t);
    t = gameboard.getTile(y,x+1);
    ret.add(t);
    t = gameboard.getTile(y+1,x2+1);
    ret.add(t);
    t = gameboard.getTile(y+1,x2);
    ret.add(t);
    t = gameboard.getTile(y,x-1);
    ret.add(t);
    t = gameboard.getTile(y-1,x1);
    ret.add(t);

    return ret;
  }
  
  //Input: Tile array Outut: First unvisited tile (for scoring)
  Tile getNextUnvisitedTile(ArrayList<Tile> tiles) {
    for (int i=0; i<tiles.size(); i++)
      if (!tiles.get(i).visited)
        return tiles.get(i);
    return null; //no more unvisited tiles
  }
  
  //Returns "field" for a given player starting at a given tile
  ArrayList<Tile> expandFieldFrom(Tile t, Player p) {
    ArrayList<Tile> list = new ArrayList<Tile>();
    ArrayList<Tile> ret = new ArrayList<Tile>();
    list.add(t);
    
    //calculate score
    while(list.size() > 0) {
      Tile curr = list.remove(0);
      if (curr.visited) //Double neighbor
        continue;

      //Add neighbors to work through
      ArrayList<Tile> neighbors = getNeighborTiles(curr);      
      for(int i=0; i<neighbors.size(); i++) {
        Tile n = neighbors.get(i);
        if (n != null && n.open && n.visited==false && (n.clr == 6 || p.colors.contains(n.clr)))
          list.add(n);
      }
      
      if (p.colors.contains(curr.clr)) {
        curr.score = 1;
      } else if (curr.clr == 6) {
        curr.score = 2;
        for (int i=0; i<neighbors.size(); i++) {
          Tile n = neighbors.get(i);         
          if (n==null || !n.open || !p.colors.contains(n.clr))
            continue;
          if (n.clr == ((i+curr.offset) % 6))
            curr.score += 2;
        }
      }
      
      curr.visited = true;
      ret.add(curr);
    }
    /*
    for(int i=0; i<ret.size(); i++) {
      println(ret.get(i).x+","+ret.get(i).y+": "+ret.get(i).score); //DEBUG 
    }
    */
    return ret;
  }
  
  //Calculate score sum for a tile field array
  int scoreFromTiles(ArrayList<Tile> tiles) {
    if (tiles==null)
     return 0;
     
    int score = 0;
    for(int i=0; i<tiles.size(); i++)
      score += tiles.get(i).score;
    return score; 
  }
  
  //score for a player, highlight on board
  int showScore(Player p) {
    int bestscore=0, score=0;
    ArrayList<Tile> field = null, bestfield = null;
    ArrayList<Tile> candidates = getOpenPlayerTiles(p);
    //println("open player tiles: "+candidates.size()); //DEBUG
    
    //reset visited flag
    for (int i=0, sub=-5; i<=10; i++, sub++) {
      int max = 11-abs(sub);
      for (int j=0; j<max; j++) {
        gameboard.tiles.get(i).get(j).visited = false;
        gameboard.tiles.get(i).get(j).score = 0;
      }
    }
    
    //make sure all fields are considered
    Tile t = getNextUnvisitedTile(candidates);
    while (t != null) {
      field = expandFieldFrom(t, p);
      score = scoreFromTiles(field);
      //println("Field score:" +score); //DEBUG
      if (score>bestscore) {
        bestscore = score;
        bestfield = field; 
      }
      t = getNextUnvisitedTile(candidates);
    }
    
    //Reset unused tile scores
    for (int i=0, sub=-5; i<=10; i++, sub++) {
      int max = 11-abs(sub);
      for (int j=0; j<max; j++) {
        Tile tmp = gameboard.tiles.get(i).get(j);
        if (bestfield!=null && !bestfield.contains(tmp))
          tmp.score = 0;
      }
    }
    
    return scoreFromTiles(bestfield);
  }
  
  void checkGameOver() {
    boolean over = false;
    int[] colorCount = new int[7];
    for(int i=0; i<gameboard.tiles.size(); i++)
      for(int j=0; j<gameboard.tiles.get(i).size(); j++) {
        Tile t = gameboard.tiles.get(i).get(j);
        if (t.open)
          colorCount[t.clr]++; 
      }
    //one player opened all of one of his colors  
    for(int i=0; i<6; i++)
      if (colorCount[i]==13 && !freeColor(i)) {
        over = true;
        break;
      }
    if (colorCount[6] < 13) //not all jokers open?
      over = false; 

    //Game over? show scores of every player starting with first
    if (over) {
      state = 8;
      currentPlayer=0; 
    }
  }
  
  //Next player's turn
  void nextPlayer() {
     currentPlayer++;
     state = 3;
     if (currentPlayer>=players.size())
       currentPlayer=0;
  }

  //Initial allocation of colors if player size changes
  void allocateColors() {
    for(int i=0; i<players.size(); i++)
      players.get(i).colors = new ArrayList<Integer>();
      
    if (players.size()==2) {
      for(int i=0; i<players.size(); i++)
        for(int j=0; j<3; j++)
          players.get(i).colors.add(3*i+j);
    } else if (players.size()==3) {
      for(int i=0; i<players.size(); i++)
        for(int j=0; j<2; j++)
          players.get(i).colors.add(2*i+j);      
    } else {
      for(int i=0; i<players.size(); i++)
        players.get(i).colors.add(i);
    }
  }
  
  //False if not same amount of colors or player without colors
  boolean checkPlayerColors() {
    int num = players.get(0).colors.size();
    for (int i=0; i<players.size(); i++) {
      int cnum = players.get(i).colors.size();
      if (cnum == 0 || cnum != num)
        return false;
    }
    return true;
  }
  
  //Returns whether the given color number does not have an owner
  boolean freeColor(int c) {
    for (int i=0; i<players.size(); i++)
      if (players.get(i).colors.contains(c))
        return false;
    return true;
  }
  
  //Show text message in top left corner
  void drawMessage(String msg, color clr) {
    fill(clr);     
    textSize(gameboard.tilesize/2);
    textAlign(LEFT);
    text(msg, gameboard.tilesize/2, gameboard.tilesize);
    textAlign(CENTER);    
  }
  
  //Make all tiles not owned by current player darker
  void darkenForeignTiles() {
    for(int i=0; i<gameboard.tiles.size(); i++)
      for(int j=0; j<gameboard.tiles.get(i).size(); j++) {
        Tile t = gameboard.tiles.get(i).get(j);
        if (darkenTiles)
          t.darkened = t.open && !(players.get(currentPlayer).colors.contains(t.clr) || t.clr==6);
        else
          t.darkened = false;
      }
  }
  
  void draw() {
    int score = 0;
    background(255);
    strokeWeight(1);
    
    darkenForeignTiles(); //makes foreign tiles dark, if enabled
    
    switch (state) {
      case 0: //Title screen
        menu.drawTitleScreen();
        break;
      case 1: //Number of players / player order / cpu/human
        menu.drawPlayerScreen();
        break;
      case 2: //Select colors
        menu.drawPlayerScreen();
        menu.drawPlayerColors();
        break;
      case 3: //Game running - player started turn 
        //System.out.println((currentPlayer+1)+" -> "+showScore(players.get(currentPlayer))); //DEBUG
        gameboard.draw();
        drawMessage("Go, Player "+(currentPlayer+1)+"!", goodColor);
        break;
      case 4: //Game running - player turned not own card
        gameboard.draw();
        drawMessage("Not your tile :(", badColor);
        break;
      case 5: //Game running - player turned own regular tile
        gameboard.draw();
        drawMessage("Nice!", goodColor);
        break;
      case 6: //Game running - joker tile!
        gameboard.draw();
        drawMessage("Joker tile :)", goodColor);
        break;
      case 7: //Game running - swap any tiles
        gameboard.draw();
        drawMessage("Swap with any!", goodColor);
        break;
      case 8: //Game over
        gameboard.draw();
        drawMessage("Game over!", neutralColor);
        break;
      case 9: //Show scores
        score = showScore(players.get(currentPlayer));
        gameboard.draw();
        drawMessage("Player "+(currentPlayer+1)+": "+score, goodColor);
        break;
    }
  }
  
  //Click handler - takes x coord, y coord and mouse button
  void click(int x, int y, int btn) {
    Tile t = null;
    switch (state) {
      case 0: //Title screen
        state++;
        this.draw();
        break;
      case 1: //Player selection
        if (btn == LEFT) {
          state++;
        } else if (btn == RIGHT) {
          //menu.rightClickPlayer(x, y); //Toggle CPU/Human -> not implemented!
        }
        this.draw();
        break;
      case 2: //Select colors
        if (btn == LEFT) {
          if (checkPlayerColors()) {
            state = 3;
            currentPlayer = 0;
            this.draw();
          } else {
            fill(255,0,0);
            textSize(gameboard.tilesize/2);
            text("Everyone needs the", width/2, height/2);
            text("same number of colors!",width/2, height/2+gameboard.tilesize);
          }
        } else if (btn == RIGHT) {
          menu.rightClickColor(x, y);
          this.draw();
        }
        break;
      case 3: //Game running - player started turn
        t = game.gameboard.getClickedTile(x,y);
        if (t==null || t.open) //no valid tile clicked
          return; 
        game.selectedTile = t;
        t.open = t.selected = true;
        if (t.clr==6) { //Joker
          state = 6;
        } else if (players.get(currentPlayer).colors.contains(t.clr)) { //Own tile
          state = 5;
        } else { //Fail
          state = 4;
        }
        this.draw();
        break;
      case 4: //Game running - opened wrong tile
        game.selectedTile.selected = false;
        if (!freeColor(game.selectedTile.clr))
          game.selectedTile.open = false;
        nextPlayer();
        checkGameOver();
        this.draw();
        break;
      case 5: //Game running - opened own tile
        t = game.gameboard.getClickedTile(x,y);
        if (t==null) //no tile clicked
          return;
        if (t==game.selectedTile) { //Keep it there
          game.selectedTile.selected = false;
          state = 3;
          checkGameOver();
        } else if (!t.open) { //swap if clicked on not open
          game.selectedTile.selected = false;
          game.selectedTile.swapWith(t);
          nextPlayer();
          checkGameOver();
        }
        this.draw();
        break;
      case 6: //Game running - opened joker tile
        t = game.gameboard.getClickedTile(x,y);
        if (t==null) //no tile clicked
          return;
        if (btn==RIGHT) { //Keep it there
          game.selectedTile.selected = false;
          game.selectedTile.fixed = true;
          state = 3;
          checkGameOver();      
        } else {
          if (t.fixed && t.clr==6) //Cannot move placed jokers
            return;
          t.selected = true;
          game.jokerSwap = t;
          state = 7;
        }
        this.draw();
        break;
      case 7: //Game running - swap 2 arbitrary tiles because of joker
        t = game.gameboard.getClickedTile(x,y);
        if (t==null || t.clr==6 && t.fixed) //no tile clicked or clicked joker
          return;
          
        game.jokerSwap.selected = false;
        t.selected = false;
        game.jokerSwap.swapWith(t);
        
        game.selectedTile.selected = false;
        game.selectedTile.fixed = true;
        
        if (t==game.jokerSwap) //nothing swapped
          state = 3;
        else //some tiles swapped
          nextPlayer();
        checkGameOver();
        this.draw();
        break;
      case 8: //Game over
        currentPlayer = 0;
        darkenTiles = true;
        state = 9;
        this.draw();
        break;
      case 9: //Show scores
        currentPlayer++;
        if (currentPlayer==players.size()) {
          currentPlayer = 0;
          state = 0;
          game = new Game();
        }
        this.draw();
        break;
    }    
  }
  
  //Mouse wheel handler
  void wheel(int x, int y, int dir) {
    switch (state) {
      case 0: //Title screen - nothing
        break;
      case 1: //player number -> increase/decrease, realloc colors
        if (dir>0 && players.size()<=2 || dir<0 && players.size()>=6)
          return;
        if (dir<0)
          players.add(new Player(false));
        else
          players.remove(players.size()-1);
        allocateColors();
        this.draw();
        break;
      case 2: //colors screen -> move color
        menu.wheelColor(x,y,dir);
        this.draw();
        break;
      case 6: //game screen -> rotate tile
      case 7:
        Tile t = gameboard.getClickedTile(x,y);
        if (t==null || t.fixed) //not a tile or fixed tile?
          return;
        t.offset = (6 + t.offset - dir)%6;
        t.draw();
    }    
  }  
}

class SettingsInterface {
  Game g;
 
  //relative center and radius of selection circle
  int rx;
  int ry;
  int r;

  //Used text colors
  color titleColor = color(0, 102, 153);
  color titleColor2 = color(0, 102, 153, 192);
  
  SettingsInterface(Game g) {
    this.g = g;
    calculateSizes();
  }
  
  void calculateSizes() {
    rx = width/2;
    ry = height/2+height/20;
    r = height/3;    
  }

  void drawTitleScreen() {
    textSize(g.gameboard.tilesize);
    fill(titleColor);
    text(g.gametitle, width/2, height/2);
    textSize(g.gameboard.tilesize/4);
    fill(titleColor2);
    text("implemented by Anton Pirogov", width/2, height/3*2); 
  }
  
  //Show player number selection
  void drawPlayerScreen() {
    int nump = g.players.size();
    textSize(g.gameboard.tilesize*3/4);
    fill(0);
    text("Number of players: "+g.players.size(), width/2, height/10);    
    for(int i=0; i<nump; i++) {
      float angle = -PI/2+2*PI/nump*i;
      float cx = rx+r*cos(angle);
      float cy = ry+r*sin(angle);
      fill(titleColor);
      ellipse(cx, cy, g.gameboard.tilesize, g.gameboard.tilesize);
      if (g.players.get(i).isCpu)
        fill(255,0,0);
      else
        fill(255);
      textSize(g.gameboard.tilesize/4*3);
      text(i+1, cx, cy+g.gameboard.tilesize/16*3);
    }
  }
  
  //Show color assignment selection
  void drawPlayerColors() {
    textSize(g.gameboard.tilesize/2);
    fill(128,128,128);
    text("Color selection", width/2, height/10*1.5);
    
    int nump = g.players.size();
    for(int i=0; i<nump; i++) {
      float angle = -PI/2+2*PI/nump*i;
      float cx = rx+r*cos(angle);
      float cy = ry+r*sin(angle);
      int numc = g.players.get(i).colors.size();
      for(int j=0; j<numc; j++) {
        float tx = cx-(j+1)*g.gameboard.tilesize/2*cos(angle);
        float ty = cy-(j+1)*g.gameboard.tilesize/2*sin(angle);
        Tile t = new Tile();
        t.clr = g.players.get(i).colors.get(j);
        t.open = true;
        t.draw(tx,ty,g.gameboard.tilesize/2);
      }
    }    
  }
  
  //toggles a player to cpu
  void rightClickPlayer(int x, int y) {
    int num = g.players.size();
    for (int i=0; i<num; i++) {
      float angle = -PI/2+2*PI/num*i;
      float cx = rx+r*cos(angle);
      float cy = ry+r*sin(angle);
      float xdist = x-cx;
      float ydist = y-cy;
      float dist = sqrt(xdist*xdist+ydist*ydist);
      if (dist <= g.gameboard.tilesize/2) {
        g.players.get(i).isCpu = !g.players.get(i).isCpu;
        return; 
      }
    }       
  }
  
  //Returns [player,index] of clicked color or null
  int[] getClickedColor(int x, int y) {
    int nump = g.players.size();
    for(int i=0; i<nump; i++) {
      float angle = -PI/2+2*PI/nump*i;
      float cx = rx+r*cos(angle);
      float cy = ry+r*sin(angle);
      int numc = g.players.get(i).colors.size();
      for(int j=0; j<numc; j++) {
        float tx = cx-(j+1)*g.gameboard.tilesize/2*cos(angle);
        float ty = cy-(j+1)*g.gameboard.tilesize/2*sin(angle);
        float xdist = x-tx;
        float ydist = y-ty;
        float dist = sqrt(xdist*xdist+ydist*ydist);
        if (dist <= g.gameboard.tilesize/4) {
          int[] ret = new int[2];
          ret[0] = i;
          ret[1] = j;
          return ret;
        }
      }
    }
    return null; 
  }
  
  //Deletes a color or resets the color allocation
  void rightClickColor(int x, int y) {
    int[] ret = getClickedColor(x,y);
    if (ret==null) //Click somewhere else -> reset allocation/restore deleted
      g.allocateColors();
    else { //delete clicked color
      g.players.get(ret[0]).colors.remove(ret[1]);
    }
  }
  
  //Move colors between players
  void wheelColor(int x, int y, int dir) {
    int[] ret = getClickedColor(x,y);
    if (ret==null)
      return;
      
    int nump = g.players.size();
    int c = g.players.get(ret[0]).colors.remove(ret[1]);
    g.players.get((nump+ret[0]+dir)%nump).colors.add(c);
  }
}

class Board {
  ArrayList<ArrayList<Tile>> tiles; //Tile array
  
  int tilesize; //size (width) of a single tile
  
  //center of the board
  int center_x; 
  int center_y;
  
  //calculate board center and tile size depending on screen
  void calculateSizes() {
    tilesize = (height>width ? width : height)/10;
    center_x = width/2;
    center_y = height/2;
  }
  
  //Generate a new serendipity board
  Board() {
    calculateSizes();
    
    //add all tile colors
    ArrayList<Integer> order = new ArrayList<Integer>();
    for(int i=0; i<7; i++)
      for(int j=0; j<13; j++)
        order.add(i);
    
    //shuffle
    for(int i=0; i<7*13*3; i++)
      order.add(order.remove(int(random(7*13))));
    
    //create tile arrays
    tiles = new ArrayList<ArrayList<Tile>>();
    for (int i=-5; i<=5; i++) {
      int max = 11-abs(i);
      ArrayList<Tile> row = new ArrayList<Tile>();
      for (int j=-max/2; j<=max/2; j++) {
        if (i%2!=0 && j==0) j++;
        row.add(new Tile(this, j, i, false, order.remove(0), int(random(6))));
      }
      tiles.add(row);
    }
  }
  
  //draws the serendipity board
  void draw() {
    for (int i=0, sub=-5; i<=10; i++, sub++) {
      int max = 11-abs(sub);
      for (int j=0; j<max; j++)
        tiles.get(i).get(j).draw();
    }
  }
  
  //Input: Mouse Click coordinates, Output: Nearest tile (if in realistic range)
  Tile getClickedTile(int mx, int my) {
    Tile nearest = null;
    float dist = 1000;
    for (int i=0, sub=-5; i<=10; i++, sub++) {
      int max = 11-abs(sub);
      for (int j=0; j<max; j++) {
        Tile t = tiles.get(i).get(j);
        int[] pos = t.getTileCenter();
        int xdist = mx-pos[0];
        int ydist = my-pos[1];
        float newdist = sqrt(xdist*xdist+ydist*ydist);
        if (newdist < dist) {
          nearest = t;
          dist = newdist; 
        }
      }
    }
    if (dist > tilesize/2)
      return null;
    return nearest;
  }
  
  //Handy method to get tiles (return null if out of bounds)
  Tile getTile(int y, int x) {
    if (y<0 || y>=tiles.size())
      return null;
    if (x<0 || x>=tiles.get(y).size())
      return null;
    return tiles.get(y).get(x);
  }

}

class Tile {
  Board parent; //gameboard this tile belongs to
  
  int x=0; //relative coordinates (0,0 = central tile)
  int y=0;
  boolean open=false; //is the card opened yet?
  
  //other state flags
  boolean fixed=false; //can not be moved anymore
  
  boolean selected = false; //Clicked on by a player for a reason
  boolean darkened = false; //Showed dark because not owned by current player
  boolean visited = false; //visited node by scoring algorithm
  int score = 0; //assigned score

  //Valid regular tile colors
  color[] colors = {color(255,0,0),color(255,128,0),color(255,255,0),color(0,255,0),color(0,0,255),color(255,0,255)};
  color backcolor = color(128,128,128);

  int clr=0; //Tile color (0-6, 6=joker)
  int offset=0; //Tile offset (joker rotation)
  
  /* create uninitialized tile */
  Tile() {
  }
  
  Tile(Board b, int x, int y, boolean o, int c, int off) {
    this.parent = b;
    this.x = x;
    this.y = y;
    this.open = o;
    this.clr = c;
    this.offset = off;
  }
  
  //get absolute coordinates of the tile center on the screen
  int[] getTileCenter() {
    final int sz = parent.tilesize;
    int[] pos = new int[2];
    
    pos[0] = parent.center_x + sz*x - sz/8*x;
    pos[1] = parent.center_y + sz*y - sz/4*y;
    if (y%2!=0)
      pos[0] +=-sz/2*(x/abs(x))+sz/16*(x/abs(x));
      
    return pos;
  }
  
  //returns tile index coordinates (y,x pos in board array)
  int[] getTileCoords() {
    int[] pos = new int[2];
    for (int i=0, sub=-5; i<=10; i++, sub++) {
      int max = 11-abs(sub);
      for (int j=0; j<max; j++)
        if (parent.tiles.get(i).get(j) == this) {
          pos[0] = i;
          pos[1] = j;
          return pos;
        }
    }
    return null;
  }
  
  //Swap this tile with another tile (position)
  void swapWith(Tile t) {
    int[] mypos = getTileCoords();
    int[] tpos = t.getTileCoords();
    
    parent.tiles.get(mypos[0]).set(mypos[1], t);
    parent.tiles.get(tpos[0]).set(tpos[1], this);
        
    int cx = this.x;
    int cy = this.y;
    this.x = t.x;
    this.y = t.y;
    t.x = cx;
    t.y = cy;
  }
  
  //Draws hex with given tilesize depending on attributes on relative 0,0
  void draw_hex(int sz) {
    strokeWeight(2);
    
    if (clr==6 && open) { //joker colors
      float angle = -3*PI/6;
      float px_old = 0;
      float py_old = 0;
      float px = sz/2*cos(angle);
      float py = sz/2*sin(angle);
      
      for(int i=0; i<6; i++) {
        angle += PI/3;
        px_old = px;
        py_old = py;
        px = sz/2*cos(angle);
        py = sz/2*sin(angle);
        
        fill(colors[(i+offset)%6]);
        stroke(colors[(i+offset)%6]);
        
        beginShape();
        vertex(0,0);
        vertex(px,py);
        vertex(px_old,py_old);
        endShape(CLOSE);
      }
    }
    
    fill(backcolor);
    
    stroke(0);
    if (selected)
      stroke(255);

    if (open) {
      if (clr<6) { // regular tile
        fill(colors[clr]);
      }
      else
        noFill(); // joker
    }
    
    beginShape();
    float angle = PI/6;
    for(int i=0; i<6; i++) {
      vertex(sz/2*cos(angle),sz/2*sin(angle));
      angle += PI/3;
    }
    endShape(CLOSE);
    
    if (darkened) {
      fill(0,0,0,192); 
      beginShape();
      angle = PI/6;
      for(int i=0; i<6; i++) {
        vertex(sz/2*cos(angle),sz/2*sin(angle));
        angle += PI/3;
      }
      endShape(CLOSE);      
    }
    
    if (score>0 && open) {
      textSize(sz/2);
      fill(255);
      text(score, 0, sz/8); 
    }
  }    

  //draw tile centered on absolute coordinates given
  //Only use directly for tiles not on a board, otherwise use draw()
  //with correctly initialized tiles and game boards
  void draw(float pos_x, float pos_y, int sz) {
    pushMatrix();
    translate(pos_x,pos_y);
    draw_hex(sz);
    popMatrix();    
  }
  
  //Draw a tile at a given coordinate with given outer radius in a given color(0-5), if clr=6 -> joker tile, offset=rotation
  void draw() {
    final int sz = parent.tilesize;
    pushMatrix();
    translate(parent.center_x,parent.center_y);
    translate(sz*x - sz/8*x, sz*y - sz/4*y);
    if (y%2!=0)
      translate(-sz/2*(x/abs(x))+sz/16*(x/abs(x)),0);  
      
    draw_hex(parent.tilesize);

    popMatrix();
  }
}

class Player {
  boolean isCpu = false;
  ArrayList<Integer> colors;
 
  Player(boolean cpu) {
    this.isCpu = cpu;
    colors = new ArrayList<Integer>();
  } 
}

