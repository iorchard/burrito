pbos.haproxy
======================

Ansible role to install haproxy for PBOS

Requirements
------------

This role requires Ansible 2.11 or higher.

This role supports:

  - Debian 11 (bullseye)

Role Variables
--------------

[defaults/main.yml](defaults/main.yml)

Dependencies
------------

[ansible-galaxy-requirements.yml](ansible-galaxy-requirements.yml)

Example Playbook
----------------

Including an example of how to use your role (for instance, with variables passed in as parameters) is always nice for users too:

    hosts: servers
    roles:
      - {role: pbos.haproxy, tags: haproxy}

HAProxy is installed on the node in controller inventory group:

    [controller]
    host-1
    host-2
    host-3

License
-------

  - Code released under [Apache License 2.0](LICENSE)
  - Docs released under [CC BY 4.0](http://creativecommons.org/licenses/by/4.0/)

Author Information
------------------

  - Heechul Kim @iOrchard
      - <https://github.com/iorchard>

