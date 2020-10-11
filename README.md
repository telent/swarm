# SWARM

a.k.a Service Watcher and Autonomous Restart Monitor
(acronym subhject to change)

## Motivation

* We get data from our ISP via DHCP6 and router advertisements, which
  we can use to dynamically control services. Typically this means
  changing a config file and then either restarting or reloading some
  process

* services often have state machines more complicated than "on" or "off",
  we don't want to start a service when the one we only just started
  is still initialising

  * for example we would like to poll the xl2tpd control socket to get
    l2tp tunnel health, then we could wait until it's set up before
    trying to start a session over it.

* we'd like to know when processes die without relying on pids (racey)

* perhaps some day we could do secrets updates through this mechanism
  as well: e.g. push a new root ssh key onto the device and have ssh restart
  

## Design

Every service in NixWRT represents its state to other services in a
directory /run/services/servicename. Within this directory we expect to
find (up to) two files with standardized names, plus a subdirectory named
'state' with whatever other values it may want to make available

/run/services/servicename/healthy
 - exists iff the service is healthy
/run/services/servicename/status
 - one-word description of the current service status (which is
   arbitrary, but could be something like "online", "starting",
   "shutting-down", "no-carrier" ...)
/run/services/servicename/state/
 - a directory containing any state the service wants to export. e.g.
/run/services/odhcp6c/state/l2tp_aaisp/ra_prefixes/1
                                                 .../prefix: 2001:8b0:de3a:40dc::
                                                 .../length: 64
                                                 .../valid: 7200
                                                 .../preferred: 7200
/run/services/odhcp6c/state/l2tp_aaisp/rdnss/1
2001:8b0::2020
/run/services/odhcp6c/state/l2tp_aaisp/rdnss/2
2001:8b0::2021
/run/services/eth0.1/state/carrier
no
/run/services/eth0.1/state/promisc
no
/run/services/eth0.1/state/packets/rx
17489375
/run/services/eth0.1/state/packets/tx
8201817

This data is maintained by a small lua script which is responsible for
starting/monitoring/restarting/repairing the underlying
process/interface/device/thing that provides the service. Where the
service is dependent on other services, it receives updates from them
by using inotify file watches on their service runtime directories.
It can use these notifications to rewrite configuration files,
restart/reload daemons, etc,

### Repair

The lua script is at liberty to check on the thing it's managing
periodically, and stage an intervention in any condition where (1) the
service is not healthy; and (2) there is an appropriate intervention
to be made.  For example

- the interface is up => no intervention
- process was recently started and not ready yet => no intervention
- interface is down because no cable => no intervention
- interface is down because kernel oops => reload module
- the process is consuming 90% of available ram => kill and restart
- the process has exited => restart

if a service is unhealthy because one of its dependencies is unhealthy, 
we will not intervene until the underlying thing comes good

each healing intervention is associated with a backoff time (or "expected
time to resolution") during which no other intervention will be
attempted

probably it would be good to have a medical history so we don't get
trapped in an infinite loop of trying the same thing over and over and
it continuing to not work.

