package e2etests

import (
	"encoding/hex"
	"fmt"
	"io"
	"math/rand"
	"testing"
	"time"

	"github.com/companyzero/bisonrelay/client"
	"github.com/companyzero/bisonrelay/internal/assert"
	"github.com/companyzero/bisonrelay/rpc"
	"github.com/companyzero/bisonrelay/zkidentity"
)

func assertClientsKXd(t testing.TB, alice, bob *testClient) {
	t.Helper()
	var gotAlice, gotBob bool
	for i := 0; (!gotAlice || !gotBob) && i < 100; i++ {
		if alice.UserExists(bob.PublicID()) {
			gotAlice = true
		}
		if bob.UserExists(alice.PublicID()) {
			gotBob = true
		}
		time.Sleep(time.Millisecond * 100)
	}
	if !gotAlice || !gotBob {
		t.Fatalf("KX did not complete %v %v", gotAlice, gotBob)
	}
}

// assertClientInGC asserts that `c` sees itself as a member of the GC.
func assertClientInGC(t testing.TB, c *testClient, gcID zkidentity.ShortID) {
	t.Helper()
	for i := 0; i < 100; i++ {
		_, err := c.GetGC(gcID)
		if err == nil {
			return
		}
		time.Sleep(time.Millisecond * 100)
	}
	t.Fatalf("Client did not join GC %s before timeout", gcID)
}

// assertClientSeesInGC asserts that `c` sees the target user as a member of the
// GC.
func assertClientSeesInGC(t testing.TB, c *testClient, gcID, target zkidentity.ShortID) {
	t.Helper()
	for i := 0; i < 100; i++ {
		gc, err := c.GetGC(gcID)
		if err != nil {
			continue
		}

		for _, uid := range gc.Members {
			if uid == target {
				return
			}
		}
		time.Sleep(time.Millisecond * 100)
	}
	t.Fatalf("Client does not see target %s as part of GC %s", target, gcID)
}

// assertClientUpToDate verifies the client has no pending updates to send
// to the server.
func assertClientUpToDate(t testing.TB, c *testClient) {
	t.Helper()
	var err error
	for i := 0; i < 200; i++ {
		err = nil
		if !c.RVsUpToDate() {
			err = fmt.Errorf("RVs are not up to date in the server")
		} else if q, s := c.RMQLen(); q+s != 0 {
			err = fmt.Errorf("RMQ is not empty")
		}
		if err != nil {
			time.Sleep(10 * time.Millisecond)
		}
	}
	if err != nil {
		t.Fatal(err)
	}
}

// assertClientsCanPM asserts that the clients can PM each other.
func assertClientsCanPM(t testing.TB, alice, bob *testClient) {
	t.Helper()
	aliceChan, bobChan := make(chan string, 1), make(chan string, 1)
	aliceReg := alice.NotificationManager().RegisterSync(client.OnPMNtfn(func(user *client.RemoteUser, msg rpc.RMPrivateMessage, ts time.Time) {
		aliceChan <- msg.Message
	}))
	bobReg := bob.NotificationManager().RegisterSync(client.OnPMNtfn(func(user *client.RemoteUser, msg rpc.RMPrivateMessage, ts time.Time) {
		bobChan <- msg.Message
	}))

	// Cleanup afterwards so we can do it multiple times.
	defer aliceReg.Unregister()
	defer bobReg.Unregister()

	aliceMsg, bobMsg := alice.name+"->"+bob.name, bob.name+"->"+alice.name
	assert.NilErr(t, alice.PM(bob.PublicID(), aliceMsg))
	assert.NilErr(t, bob.PM(alice.PublicID(), bobMsg))
	assert.ChanWrittenWithVal(t, aliceChan, bobMsg)
	assert.ChanWrittenWithVal(t, bobChan, aliceMsg)
}

// assertClientsCanGCM asserts that the clients can send GC messages to each
// other inside a GC.
func assertClientsCanGCM(t testing.TB, gcID zkidentity.ShortID, clients ...*testClient) {
	regs := make([]client.NotificationRegistration, len(clients))
	chans := make([]chan string, len(clients))

	// Setup all handlers.
	for i := range clients {
		i := i
		chans[i] = make(chan string, 1)
		regs[i] = clients[i].handle(client.OnGCMNtfn(func(_ *client.RemoteUser, msg rpc.RMGroupMessage, _ time.Time) {
			chans[i] <- msg.Message
		}))
	}

	// Send one message from each client and ensure the other ones receive
	// it.
	for i := range clients {
		wantMsg := fmt.Sprintf("msg from %d - %s", i, clients[i].name)
		err := clients[i].GCMessage(gcID, wantMsg, 0, nil)
		assert.NilErr(t, err)
		for j := range clients {
			if i == j {
				continue
			}

			assert.ChanWrittenWithVal(t, chans[j], wantMsg)
		}
	}

	// Teardown the handlers.
	for i := range clients {
		regs[i].Unregister()
	}
}

// assertClientCannotSeeGCM asserts that a GCM send by the source client is not
// received by the target client.
func assertClientCannotSeeGCM(t testing.TB, gcID zkidentity.ShortID, src, target *testClient) {
	c := make(chan string, 1)
	reg := target.handle(client.OnGCMNtfn(func(_ *client.RemoteUser, msg rpc.RMGroupMessage, _ time.Time) {
		c <- msg.Message
	}))

	msg := fmt.Sprintf("msg from %s not seen by %s", src.name, target.name)
	err := src.GCMessage(gcID, msg, 0, nil)
	assert.NilErr(t, err)
	assert.ChanNotWritten(t, c, time.Millisecond*500)
	reg.Unregister()
}

func testRand(t testing.TB) *rand.Rand {
	seed := time.Now().UnixNano()
	rnd := rand.New(rand.NewSource(seed))
	t.Cleanup(func() {
		if t.Failed() {
			t.Logf("Seed: %d", seed)
		}
	})

	return rnd
}

func randomHex(rnd io.Reader, len int) string {
	b := make([]byte, len)
	_, err := rnd.Read(b)
	if err != nil {
		panic(err)
	}
	return hex.EncodeToString(b)
}
