//
// Polycode template. Write your code here.
// 

#include "PolycodeTemplateApp.h"
#include "program.h"
#include "terminal.h"
#include "playtest.h"

#if SELF_EDIT
#include <unistd.h>
#include "physfs.h"
#endif

// File prefix?
#ifdef __APPLE__
#define FP ""
#else
#define FP "Internal/"
#endif

#if SELF_EDIT
#define FULLSCREEN 0
#else
#define FULLSCREEN 1
#endif

#if FULLSCREEN
#define SCREENMOD 1
#else
#define SCREENMOD 0.75
#endif

#define CALC_ASPECT (1280.0/800)

PolycodeView *appView = NULL;

PolycodeTemplateApp::PolycodeTemplateApp(PolycodeView *view) {
	appView = view;
	{
		time_t rawtime;
		time ( &rawtime );
		srandom(rawtime);
	}
	
	CoreServices::getInstance()->getScreenInfo(&fullscreen_width, &fullscreen_height, NULL);
#if FULLSCREEN
	surface_width = fullscreen_width;
	surface_height = fullscreen_height;
#else
	surface_width = fullscreen_width*SCREENMOD;
	surface_height = surface_width/CALC_ASPECT;
#endif
	sbound = cpbounds(cpvzero,cpv(surface_width, surface_height));

#if defined(__APPLE__)
	core = new CocoaCore(view, surface_width,surface_height,FULLSCREEN,true, 0,0,60);
#elif defined(_WINDOWS)
	core = new Win32Core(view, surface_width,surface_height,FULLSCREEN,true, 0,0,60);
#else
	core = new SDLCore(view, surface_width,surface_height,FULLSCREEN,true, 0,0,60);
#endif
	cor = core;
	
	CoreServices::getInstance()->getRenderer()->setTextureFilteringMode(Renderer::TEX_FILTERING_NEAREST);
	
	CoreServices::getInstance()->getResourceManager()->addArchive(FP"default.pak");
	CoreServices::getInstance()->getResourceManager()->addDirResource("default");

	CoreServices::getInstance()->getResourceManager()->addArchive(FP"api.pak");
	CoreServices::getInstance()->getResourceManager()->addArchive(FP"project.pak");

#if PHYSICS2D
	CoreServices::getInstance()->getResourceManager()->addArchive(FP"physics2d.pak");
#endif
#if PHYSICS3D
	CoreServices::getInstance()->getResourceManager()->addArchive(FP"physics3d.pak");
#endif
	
#if SELF_EDIT
	{
		// In SELF_EDIT mode, rather than loading the media.pak archive we will attempt to load live data directly
		// out of media/. We do this by assuming that relative to the repository root, we are running in
		// "build/Debug/PolycodeTemplate.app/Contents/Resources"; we strip off five levels of dirs from the cwd
		// to get to the repository root, then add the result to the PhysFS search paths.
		char *cwd = getcwd(NULL, NULL);
		int slashes = 0;
		ERR("Full path %s\n", cwd);
		for(int c = strlen(cwd)-1; c >= 0; c--) {
			if (cwd[c] == '/')
				slashes++;
			if (slashes >= 5) {
				cwd[c+1] = '\0';
				break;
			}
		}
		ERR("Will look for media dir in %s\n", cwd);
		PHYSFS_addToSearchPath (cwd, true);
		free(cwd);
	}
#else
	CoreServices::getInstance()->getResourceManager()->addArchive(FP"media.pak");
#endif	
	
	CoreServices::getInstance()->getResourceManager()->addDirResource("media/material", false);

	save.load(); // Game save file
	
	(new terminal_auto())->insert();
	
	terminal_auto *terminal = terminal_auto::singleton();
	terminal->inject_global("surface_height", surface_height);
	terminal->inject_global("surface_width",  surface_width);
	terminal->inject_global("scale",		  surface_height/800.0);
	terminal->inject_global("line_height",	  terminal->line_height);
	terminal->inject_global("max_width",	  terminal->max_width);
	terminal->inject_global("max_height",	  terminal->max_height);
#if _DEBUG
	terminal->inject_global("_DEBUG",		  1);
#endif
		
#if PLAYTEST_RECORD
	(new recorder_auto())->insert();
#endif
	
	(new room_auto(filedump("media/init.txt")))->insert();
}

PolycodeTemplateApp::~PolycodeTemplateApp() {
    
}

// Function

list<automaton *> automata;
vector<auto_iter> dying_auto;
Core *cor;
int ticks = 0;
int fullscreen_width, fullscreen_height, surface_width, surface_height;
cpRect sbound = cpr(cpvzero,cpvzero);

automaton::automaton() : EventHandler(), done(false), born(ticks), frame(0), state(0), rollover(1) {}

void automaton::tick() {
	if (done) return;
	
    if (age() > 0) {
        frame++;
    }
    if (frame > rollover) {
        state++;
        rollover = 0;
    }
}

void automaton::die() {
	done = true;
	
	for(int c = 0; c < owned_screen.size(); c++)
		delete owned_screen[c];
	owned_screen.clear();
	
    dying_auto.push_back(anchor);
}

bool PolycodeTemplateApp::Update() {
	ticks++;
	
	// TODO: Can all this be done with the polycode primitives?
	for(auto_iter i = automata.begin(); i != automata.end(); i++) {
        (*i)->tick();
    }            
	if (!dying_auto.empty()) {
        for(int c = 0; c < dying_auto.size(); c++) {
            automaton *a = *dying_auto[c];
            automata.erase(dying_auto[c]);
            delete a;
        }
        dying_auto.clear();
    }    
	
    return cor->Update();
}

void Quit() {
#ifdef _WINDOWS
	PostMessage(appView->hwnd, WM_CLOSE, NULL, NULL);
#else
	exit(0);
#endif
}