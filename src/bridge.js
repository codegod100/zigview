// Elm to JavaScript bridge for file browser functionality
let app = null;
let pendingFiles = null;

function initElm() {
    if (typeof Elm !== 'undefined') {
        app = Elm.Main.init({
            node: document.getElementById('elm-app')
        });

        // Send any pending files that arrived before Elm was ready
        if (pendingFiles !== null && app && app.ports && app.ports.onFilesLoaded) {
            app.ports.onFilesLoaded.send(pendingFiles);
            pendingFiles = null;
        }

        // Subscribe to file load requests from Elm
        if (app.ports && app.ports.sendLoadFiles) {
            app.ports.sendLoadFiles.subscribe(function(path) {
                if (typeof loadFilesFromZig === 'function') {
                    loadFilesFromZig(path);
                } else {
                    console.error("loadFilesFromZig is not defined");
                }
            });
        }
        
        console.log('Elm app initialized');
    }
}

// Function to be called from Zig with file list data
window.onFilesFromZig = function(filesJson) {
    console.log('Files loaded from Zig:', filesJson);
    if (app && app.ports && app.ports.onFilesLoaded) {
        app.ports.onFilesLoaded.send(filesJson);
    } else {
        // Store for later if Elm not ready yet
        pendingFiles = filesJson;
    }
};

// Initialize when DOM is ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initElm);
} else {
    initElm();
}
