#!/usr/bin/env bash
# vim:filetype=sh
set -o errexit
set -o pipefail

main() {
  if [[ ! "${QUIET}" ]]; then
    set -o xtrace
  fi

  : "${RUNDIR:=/var/tmp/travis-run.d}"

  __setup_travis_user
  __install_packages
  __setup_sysctl
  __setup_iptables

  hostname >"${RUNDIR}/instance-hostname.tmpl"
}

__setup_travis_user() {
  : "${RUNDIR:=/var/tmp/travis-run.d}"

  if ! getent passwd travis &>/dev/null; then
    useradd travis
  fi

  chown -R travis:travis "${RUNDIR}"
}

__install_packages() {
  apt-get install -yqq iptables-persistent
}

__setup_sysctl() {
  # NOTE: we do this mostly to ensure file IO chatty services like mysql will
  # play nicely with others, such as when multiple containers are running mysql,
  # which is the default on precise + trusty.  The value we set here is 16^5,
  # which is one power higher than the default of 16^4 :sparkles:.
  echo 1048576 >/proc/sys/fs/aio-max-nr
  sysctl -w fs.aio-max-nr=1048576

  echo 1 >/proc/sys/net/ipv4/ip_forward
  sysctl -w net.ipv4.ip_forward=1
}

__setup_iptables() {
  local pub_iface priv_iface elastic_ip
  pub_iface="$(__find_public_interface)"
  priv_iface="$(__find_private_interface)"
  elastic_ip="$(__find_elastic_ip)"

  iptables -t nat -A POSTROUTING -o "${pub_iface}" -j SNAT --to "${elastic_ip}"
  iptables -t nat -A POSTROUTING -o "${pub_iface}" -j MASQUERADE
  iptables -A FORWARD -i "${pub_iface}" -o "${priv_iface}" \
    -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
  iptables -A FORWARD -i "${priv_iface}" -o "${pub_iface}" -j ACCEPT
}

__find_private_interface() {
  # FIXME: dynamically do
  echo enp2s0d1
}

__find_public_interface() {
  # FIXME: dynamically do
  echo bond0
}

__find_elastic_ip() {
  # FIXME: inject this from somewhere?
  echo 127.0.0.1
}

main "$@"
