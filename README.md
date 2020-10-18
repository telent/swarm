# SWARM

a.k.a Service Watcher and Autonomous Restart Monitor
(acronym subject to change)

[ This README is aspirational not definitional.  It describes the
  future that (we think) we'd like, not the present that we have ]


## Motivation

* We want to start and monitor services (daemons etc) in NixWRT and
  respond more quickly to changes in their state than by polling them
  every thirty seconds as currently happens

* services often have state machines more complicated than "on" or "off",
  which informs how the service monitor should treat them.  For example,
  we don't want to start a service when the one we only just started
  is still initialising

  * for example we would like to poll the xl2tpd control socket to get
    l2tp tunnel health, then we could wait until it's set up before
    trying to start a session over it.

* A specific use case: we get data from our ISP via DHCP6 and Router
  Advertisements using odhcp6c. odhcp6c runs a script whenever the
  upstream sends new information, which is responsible for
  reconfiguring all relevant LAN interfaces, possibly the DHCP and
  local DNS services, etc. Why should odhcp6c have to know what its
  downstreams are and how to reconfigure them? We want pubsub!

* we'd like to know when processes die without relying on pids (racey)

* perhaps in future we could do secrets updates or other remote
  reconfig through this mechanism as well: e.g. push a new root ssh
  key onto the device and have ssh restart, or poll an HTTP server
  for an external list of suspect IP addresses that interested services
  could subscribe to, to deny service 

* I've added Lua to the NixWRT image anyway because writing shell
  scripts in Busybox `sh` is not scalable beyond ~ 10 lines, so I
  may as well get some use for it

## Design

Every service in NixWRT represents its state to other services in a
directory /run/services/servicename. Within this directory we expect
to find (up to) two files with standardized UPPERCASE names, plus a an
arbitrary number of other files (and directories) with lowercase names
containing whatever other state it may want to make available.  This
might be something like


```
/run/services/servicename/HEALTHY
35235.123
 - exists if the service is healthy. Contains monotonic timestamp of
   most recent health check (as provided by clock_gettime with CLOCK_MONOTONIC)
/run/services/servicename/STATUS
showtime
 - one-word description of the current service status (which is
   arbitrary, but could be something like "online", "starting",
   "shutting-down", "no-carrier" ...)
/run/services/odhcp6c/l2tp_aaisp/ra_prefixes/1
/run/services/odhcp6c/l2tp_aaisp/ra_prefixes/1/prefix
2001:8b0:de3a:40dc::
/run/services/odhcp6c/l2tp_aaisp/ra_prefixes/1/length
64
/run/services/odhcp6c/l2tp_aaisp/ra_prefixes/1/valid
7200
/run/services/odhcp6c/l2tp_aaisp/ra_prefixes/1/preferred
7200
/run/services/odhcp6c/l2tp_aaisp/rdnss/1
2001:8b0::2020
/run/services/odhcp6c/l2tp_aaisp/rdnss/2
2001:8b0::2021
/run/services/eth0.1/carrier
no
/run/services/eth0.1/promiscuous
no
/run/services/eth0.1/packets/rx
17489375
/run/services/eth0.1/packets/tx
8201817
```

For each service, this data is maintained by a small Lua script
(see e.g. [ethernet.lua](example/ethernet.lua)) which
is responsible for starting/monitoring/restarting/repairing the
underlying process/interface/device/other thing that provides the associated
service. Where the service is dependent on other services, it receives
updates from them by using inotify file watches on _their_ service
runtime directories.  It can use these notifications to rewrite
configuration files, restart/reload daemons, run commands, etc.


## To build

    nix-build --arg stdenv '(import <nixpkgs> {}).stdenv' .

## To run the example service swarm

    $ nix-shell
    nix-shell$ make
    nix-shell$ (cd example/ && env PATH=../src:$PATH foreman start)

## To run tests

    $ nix-shell
    nix-shell$ make test


----

# WIP and rumination

### Repair

The Lua script is expected/recommended to check periodically on the
thing it's managing, and stage an intervention in any condition where
(1) the service is not healthy; and (2) there is an appropriate
intervention to be made.  For example

- the interface is up => no intervention
- the process was recently started and not ready yet => no intervention
- interface is down because no cable => no intervention
- interface is down because kernel oops => reload module
- the process is consuming 90% of available ram => kill and restart
- the process has exited => restart

If a service is unhealthy because one of its dependencies is unhealthy, 
we will not intervene until the underlying thing comes good.

Each healing intervention is associated with a backoff time (or "expected
time to resolution") during which no other intervention will be
attempted

Probably it would be good to have a medical history so we don't get
trapped in an infinite loop of trying the same thing over and over and
it continuing to not work.
