# Mega
The hallucinator machine.

---

sudo apt-get install build-essential libnspr4 libnss3 clang cmake ninja-build pkg-config -y

---

wget https://go.dev/dl/go1.26.4.linux-amd64.tar.gz

tar -xvf go1.26.4.linux-amd64.tar.gz

rm -rf go1.26...

mkdir .go

---

mkdir bin

wget https://github.com/tailwindlabs/tailwindcss/releases/download/v4.3.3/tailwindcss-linux-arm64 -O bin/tailwindcss

chmod +x bin/tailwindcss

---

wget android.studio.deb

sudo dpkg -i android.studio.deb

---

.bashrc:

export GOROOT=$HOME/go

export GOPATH=$HOME/.go

export PATH=$PATH:$HOME/bin:$GOROOT/bin

---

tinygo

---

wget "https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64" -O vscode.deb

sudo apt install ./vscode.deb

rm -rf vscode.deb

---

func Run(cfg *config.Config) error {
	// 1. Initialization
	// Set up the router and server before binding to any OS signals.
	router, err := newRouter()
	if err != nil {
		return err
	}

	srv := newServer(cfg, router)

	// 2. Signal Context
	// Intercept OS signals (e.g., Ctrl+C, Docker stop) to initiate graceful shutdown.
	ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer cancel()

	// 3. Server Execution
	// errCh is buffered to 1 to ensure the goroutine doesn't block if the main thread has already exited.
	errCh := make(chan error, 1)
	
	go func() {
		log.Printf("server listening on %s", srv.Addr)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			errCh <- err
		}
	}()

	// 4. Wait for Termination
	// Block here until the server crashes OR the OS sends an interrupt signal.
	select {
	case err := <-errCh:
		return fmt.Errorf("server error: %w", err)
	case <-ctx.Done():
		log.Println("shutdown signal received")
	}

	// 5. Graceful Teardown
	// The code reaches here only if ctx.Done() was triggered.
	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), cfg.Server.ShutdownTimeout)
	defer shutdownCancel()

	if err := srv.Shutdown(shutdownCtx); err != nil {
		return fmt.Errorf("graceful shutdown failed: %w", err)
	}

	log.Println("server stopped cleanly")
	return nil
}
---
