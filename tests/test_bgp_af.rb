#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
# RouterBgpAF Unit Tests
#
# Richard Wellum, August, 2015
#
# Copyright (c) 2015 Cisco and/or its affiliates.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require_relative 'ciscotest'
require_relative '../lib/cisco_node_utils/bgp'
require_relative '../lib/cisco_node_utils/bgp_af'
require_relative '../lib/cisco_node_utils/feature'

# TestRouterBgpAF - Minitest for RouterBgpAF class
class TestRouterBgpAF < CiscoTestCase
  def setup
    super
    # Disable and enable feature bgp before each test to ensure we
    # are starting with a clean slate for each test.
    if platform == :nexus
      config('no feature bgp', 'feature bgp')
    elsif platform == :ios_xr
      config('no router bgp')
      config('no route-policy drop_all')
    end
  end

  # Disabling line length to support wide-format test matrix definition
  # rubocop:disable Metrics/LineLength

  # Address Families to test:
  T_AFS = [
    #   afi  safi
    %w(ipv4 unicast),
    %w(ipv6 unicast),
    %w(ipv4 multicast),
    %w(ipv6 multicast),
    %w(l2vpn evpn),

    # TODO: These are additional address families/modifiers reported by XR, should they be tested also?
    #       Looks like most of them are not supported on Nexus...
    #

    #     %w(ipv4 mvpn),
    #     %w(ipv6 mvpn),

    # Not on Nexus:
    #     %w(link-state link-state),
    #
    #     %w(l2vpn mspw),
    #     %w(l2vpn vpls-vpws),
    #
    #     %w(ipv4 flowspec),
    #     %w(ipv4 mdt),
    #     %w(ipv4 rt-filter),
    #     %w(ipv4 tunnel),
    #
    #     %w(ipv6 flowspec),
    #
    #     %w(vpnv4 unicast),
    #     %w(vpnv4 multicast),
    #     %w(vpnv4 flowspec),
    #
    #     %w(vpnv6 unicast),
    #     %w(vpnv6 multicast),
    #     %w(vpnv6 flowspec),
  ]

  # ASs to test:
  # TODO: Do we ever need to test more than one AS?
  T_ASNS = ['55']

  # VRFs to test:
  T_VRFS = %w(default red)

  # Value-based properties
  T_VALUES = [
    [:default_information_originate,  [:toggle]],
    [:client_to_client,               [:toggle]],
    [:additional_paths_send,          [:toggle]],
    [:additional_paths_receive,       [:toggle]],
    [:additional_paths_install,       [:toggle]],
    [:advertise_l2vpn_evpn,           [:toggle]],

    # TODO: To be added in future
    #    [:route_target_both_auto,         [:toggle]],
    #    [:route_target_both_auto_evpn,    [:toggle]],

    [:next_hop_route_map,             ['drop_all']],
    [:additional_paths_selection,     ['drop_all']],
    [:maximum_paths,                  [7, 9]],
    [:maximum_paths_ibgp,             [7, 9]],
    [:dampen_igp_metric,              [555, nil]],

    # TODO: To be added in future
    #    [:route_target_import,            [['1:1', '2:2', '3:3', '4:5'],['1:1', '4:4']]],
    #    [:route_target_import_evpn,       [['1:1', '2:2', '3:3', '4:5'],['1:1', '4:4']]],
    #    [:route_target_export,            [['1:1', '2:2', '3:3', '4:5'],['1:1', '4:4']]],
    #    [:route_target_export_evpn,       [['1:1', '2:2', '3:3', '4:5'],['1:1', '4:4']]],
  ]

  # Given the cartesian product of the above parameters, not all tests are supported.
  # Here we record which tests are expected to fail, and what kind of failure is expected.
  # This supports a very simple workflow for adding new tests:
  #   - Add new entry into test tables above.
  #   - Run tests.
  #   - When test fails, add a new 'exception' entry.
  #   - Repeat until test passes.
  #   - Condense entries using :any where possible.
  #
  TEST_EXCEPTIONS = [
    #  Test                           OS      VRF        AF                    Expected result

    # Tests that are successful even though a rule below says otherwise
    [:next_hop_route_map,            :nexus,  'default', %w(l2vpn evpn),       :success],

    # TODO: "address-family l2vpn evpn" drops out of "vrf red" context (XR and Nexus)
    #       This causes the getter and setter to be out of sync, thus failing the test(s)
    #       Should be able to remove this skip after fixing the CLI command generator
    [:any,                           :any,    'red',     %w(l2vpn evpn),       :skip],

    # XR Unsupported
    [:default_information_originate, :ios_xr, :any,      :any,                 :unsupported],
    [:client_to_client,              :ios_xr, 'red',     :any,                 :unsupported],
    [:additional_paths_install,      :ios_xr, :any,      :any,                 :unsupported],
    [:advertise_l2vpn_evpn,          :ios_xr, :any,      :any,                 :unsupported],
    [:maximum_paths,                 :ios_xr, :any,      %w(vpnv4 multicast),  :unsupported],
    [:maximum_paths,                 :ios_xr, :any,      %w(vpnv6 multicast),  :unsupported],

    [:maximum_paths_ibgp,            :ios_xr, :any,      %w(vpnv4 multicast),  :unsupported],
    [:maximum_paths_ibgp,            :ios_xr, :any,      %w(vpnv6 multicast),  :unsupported],
    [:dampen_igp_metric,             :ios_xr, :any,      :any,                 :unsupported],

    # XR CLI Errors
    [:additional_paths_send,         :ios_xr, :any,      %w(ipv4 multicast),   :CliError],
    [:additional_paths_send,         :ios_xr, :any,      %w(ipv6 multicast),   :CliError],
    [:additional_paths_receive,      :ios_xr, :any,      %w(ipv4 multicast),   :CliError],
    [:additional_paths_receive,      :ios_xr, :any,      %w(ipv6 multicast),   :CliError],
    [:next_hop_route_map,            :ios_xr, 'red',     %w(ipv4 unicast),     :CliError],
    [:next_hop_route_map,            :ios_xr, 'red',     %w(ipv6 unicast),     :CliError],
    [:next_hop_route_map,            :ios_xr, 'red',     %w(ipv4 multicast),   :CliError],
    [:next_hop_route_map,            :ios_xr, 'red',     %w(ipv6 multicast),   :CliError],
    [:maximum_paths,                 :ios_xr, :any,      %w(l2vpn evpn),       :CliError],
    [:maximum_paths_ibgp,            :ios_xr, :any,      %w(l2vpn evpn),       :CliError],
    [:additional_paths_selection,    :ios_xr, :any,      %w(ipv4 multicast),   :CliError],
    [:additional_paths_selection,    :ios_xr, :any,      %w(ipv6 multicast),   :CliError],

    # Nexus Unsupported
    [:any,                           :nexus,  :any,      %w(vpnv4 multicast),  :unsupported],
    [:any,                           :nexus,  :any,      %w(vpnv6 multicast),  :unsupported],

    # Nexus CLI Errors
    [:any,                           :nexus,  'default', %w(l2vpn evpn),       :CliError],
    [:additional_paths_install,      :nexus,  :any,      %w(ipv6 unicast),     :CliError],
    [:additional_paths_install,      :nexus,  :any,      %w(ipv6 multicast),   :CliError],
    [:advertise_l2vpn_evpn,          :nexus,  'default', %w(ipv4 unicast),     :CliError],
    [:advertise_l2vpn_evpn,          :nexus,  'default', %w(ipv6 unicast),     :CliError],
    [:advertise_l2vpn_evpn,          :nexus,  'default', %w(ipv4 multicast),   :CliError],
    [:advertise_l2vpn_evpn,          :nexus,  'default', %w(ipv6 multicast),   :CliError],
    [:advertise_l2vpn_evpn,          :nexus,  'red',     %w(ipv4 multicast),   :CliError],
    [:advertise_l2vpn_evpn,          :nexus,  'red',     %w(ipv6 multicast),   :CliError],
  ]

  # rubocop:disable Style/SpaceAroundOperators
  def check_test_exceptions(test_, os_, vrf_, af_)
    ret = nil
    amb = nil
    TEST_EXCEPTIONS.each do |test, os, vrf, af, expect|
      next unless (test_ == test || test == :any) &&
                  (os_   == os   || os   == :any) &&
                  (vrf_  == vrf  || vrf  == :any) &&
                  (af_   == af   || af   == :any)
      return expect if expect == :success || expect == :skip

      # Otherwise, make sure there's no ambiguity/overlap in the exceptions.
      assert_nil(ret, 'TEST ERROR: Exceptions matrix has ambiguous entries! ' \
                      "#{amb} and [#{test}, #{os}, #{vrf}, #{af}]")
      ret = expect
      amb = [test, os, vrf, af, expect]
    end
    # Return the expected test result
    ret.nil? ? :success : ret
  end
  # rubocop:enable Style/SpaceAroundOperators

  def test_properties_matrix
    T_ASNS.each do |asn|
      config_ios_xr_dependencies(asn) if platform == :ios_xr

      T_VRFS.each do |vrf|
        T_AFS.each do |af|
          puts '**************************************'
          bgp_af = RouterBgpAF.new(asn, vrf, af)

          T_VALUES.each do |test, test_values|
            puts "******** #{test}, #{asn}, #{vrf}, #{af}"

            # Override expectation for some specific cases..
            expect = check_test_exceptions(test, platform, vrf, af)

            # Gather initial and default values
            initial = bgp_af.send(test)
            default = initial.nil? ? nil : bgp_af.send("default_#{test}")
            first_value = (test_values[0] == :toggle) ? !default : test_values[0]

            if expect == :skip
              # Do nothing..
              puts '         skip'

            elsif expect == :CliError
              puts '         CliError'

              # This set of parameters produces a CLI error
              assert_raises(Cisco::CliError,
                            "Assert 'cli error' failed for: #{test}, #{asn}, #{vrf}, #{af}") do
                bgp_af.send("#{test}=", first_value)
              end

            elsif expect == :unsupported
              puts '         Unsupported'

              # Getter should return nil when unsupported?  Does not seem to work:
              #    Assert 'nil' inital value failed for: default_information_originate 55 default ["ipv4", "unicast"].
              #    Expected false to be nil.
              # assert_nil(initial, "Assert 'nil' inital value failed for: #{test} #{asn} #{vrf} #{af}")

              # Setter should raise error when unsupported
              assert_raises(Cisco::UnsupportedError,
                            "Assert 'unsupported' failed for: #{test}, #{asn}, #{vrf}, #{af}") do
                bgp_af.send("#{test}=", first_value)
              end

            else

              # Check initial value == default value
              #   Skip this assertion for properties that use auto_default: false
              assert_equal(default, initial,
                           "Initial value failed for: #{test}, #{asn}, #{vrf}, #{af}"
                          ) unless  initial.nil?

              # Try all the test values in order
              test_values.each do |test_value|
                test_value = (test_value == :toggle) ? !default : test_value

                # Try the test value
                bgp_af.send("#{test}=", test_value)
                assert_equal(test_value, bgp_af.send(test),
                             "Test value failed for: #{test}, #{asn}, #{vrf}, #{af}")
              end # test_values

              # Set it back to the default
              unless default.nil?
                bgp_af.send("#{test}=", default)
                assert_equal(default, bgp_af.send(test),
                             "Default assignment failed for: #{test}, #{asn}, #{vrf}, #{af}")
              end
            end

            # Cleanup
            bgp_af.destroy
          end # tests
        end # afs
      end # vrfs
    end # asns
  end

  # rubocop:enable Metrics/LineLength

  ##
  ## BGP Address Family
  ## Validate that RouterBgp.afs is empty when bgp is not enabled
  ##
  def test_collection_empty
    node.cache_flush
    afs = RouterBgpAF.afs
    assert_empty(afs, 'BGP address-family collection is not empty')
  end

  ##
  ## BGP Address Family
  ## Configure router bgp, some VRF's and address-family statements
  ## - verify that the final instance objects are correctly populated
  ## Enable VXLAN and the EVPN
  ##
  def test_collection_not_empty
    config('feature bgp') if platform == :nexus
    config('router bgp 55',
           'address-family ipv4 unicast',
           'vrf red',
           'address-family ipv4 unicast',
           'vrf blue',
           'address-family ipv6 multicast',
           'vrf orange',
           'address-family ipv4 multicast',
           'vrf black',
           'address-family ipv6 unicast')

    # Construct a hash of routers, vrfs, afs
    routers = RouterBgpAF.afs
    refute_empty(routers, 'Error: BGP address_family collection is empty')

    # Validate the collection
    routers.each do |asn, vrfs|
      assert((asn.kind_of? Fixnum),
             'Error: Autonomous number must be a fixed number')
      refute_empty(vrfs, 'Error: Collection is empty')

      vrfs.each do |vrf, afs|
        refute_empty(afs, 'Error: No Address Family found')
        assert(vrf.length > 0, 'Error: No VRF found')
        afs.each_key do |af_key|
          afi = af_key[0]
          safi = af_key[1]
          assert(afi.length > 0, 'Error: AFI length is zero')
          assert_match(/^ipv[46]/, afi, 'Error: AFI must be ipv4 or ipv6')
          assert(safi.length > 0, 'Error: SAFI length is zero')
        end
      end
    end
  end

  def config_ios_xr_dependencies(asn, vrf='red')
    # These dependencies are required on ios xr

    # "rd auto" required, otherwise XR reports:
    #   'The RD for the VRF must be present before an
    #        address family is activated'

    # "bgp router-id" requred, otherwise XR reports:
    #   'BGP router ID must be configured.'

    # "address-family vpnv4 unicast" required, otherwise XR reports:
    #   'The parent address family has not been initialized'

    config("router bgp #{asn}",
           'bgp router-id 10.1.1.1',
           'address-family vpnv4 unicast',
           'address-family vpnv6 unicast',
           'address-family vpnv4 multicast',
           'address-family vpnv6 multicast',
           "vrf #{vrf}", 'rd auto')

    # Needed for testing route-policy commands
    config('route-policy drop_all', 'end-policy')
  end

  ########################################################
  #                      PROPERTIES                      #
  ########################################################

  def test_dampening
    asn = '101'
    af = %w(ipv4 unicast)
    if platform == :nexus
      vrf = 'orange'
    elsif platform == :ios_xr
      vrf = 'default'
      config_ios_xr_dependencies(asn, vrf)
    end
    bgp_af = RouterBgpAF.new(asn, vrf, af)

    # Test no dampening configured
    assert_nil(bgp_af.dampening)

    ############################################
    # Set and verify 'dampening' with defaults #
    ############################################

    bgp_af.dampening = []
    assert_equal(bgp_af.default_dampening,
                 bgp_af.dampening) if platform == :nexus
    assert_equal('', bgp_af.dampening) if platform == :ios_xr

    bgp_af.dampening = nil
    assert_nil(bgp_af.dampening)
    assert_nil(bgp_af.dampening_half_time)
    assert_nil(bgp_af.dampening_reuse_time)
    assert_nil(bgp_af.dampening_suppress_time)
    assert_nil(bgp_af.dampening_max_suppress_time)
    assert_nil(bgp_af.dampening_routemap)

    #############################################
    # Set and verify 'dampening' with overrides #
    #############################################

    bgp_af.dampening = %w(1 2 3 4)

    # Check getters
    assert_equal(bgp_af.dampening, %w(1 2 3 4),
                 'Error: dampening getter did not match')
    assert_equal(1, bgp_af.dampening_half_time,
                 'The wrong dampening half_time value is configured')
    assert_equal(2, bgp_af.dampening_reuse_time,
                 'The wrong dampening reuse_time value is configured')
    assert_equal(3, bgp_af.dampening_suppress_time,
                 'The wrong dampening suppress_time value is configured')
    assert_equal(4, bgp_af.dampening_max_suppress_time,
                 'The wrong dampening max_suppress_time value is configured')
    assert_empty(bgp_af.dampening_routemap,
                 'A routemap should not be configured')

    bgp_af.dampening = nil
    assert_nil(bgp_af.dampening)
    assert_nil(bgp_af.dampening_half_time)
    assert_nil(bgp_af.dampening_reuse_time)
    assert_nil(bgp_af.dampening_suppress_time)
    assert_nil(bgp_af.dampening_max_suppress_time)
    assert_nil(bgp_af.dampening_routemap)

    #############################################
    # Set and verify 'dampening' with route-map #
    #############################################

    config('route-policy DropAllTraffic', 'end-policy') if platform == :ios_xr
    bgp_af.dampening = 'DropAllTraffic'

    # Check getters
    assert_equal(bgp_af.dampening, 'DropAllTraffic',
                 'Error: dampening getter did not match')
    assert_equal(bgp_af.dampening_routemap, 'DropAllTraffic',
                 'Error: dampening getter did not match')

    bgp_af.dampening = nil
    assert_nil(bgp_af.dampening)
    assert_nil(bgp_af.dampening_half_time)
    assert_nil(bgp_af.dampening_reuse_time)
    assert_nil(bgp_af.dampening_suppress_time)
    assert_nil(bgp_af.dampening_max_suppress_time)
    assert_nil(bgp_af.dampening_routemap)

    #############################################
    # Set and verify 'dampening' with default   #
    #############################################

    # IOS XR; we skip this section because we cannot query
    #    the default parameters
    if platform == :nexus
      bgp_af.dampening = bgp_af.default_dampening

      # Check getters
      assert_empty(bgp_af.dampening, 'Error: dampening not configured ' \
                   'and should be')
      assert_equal(bgp_af.default_dampening_half_time,
                   bgp_af.dampening_half_time,
                   'Wrong default dampening half_time value configured')
      assert_equal(bgp_af.default_dampening_reuse_time,
                   bgp_af.dampening_reuse_time,
                   'Wrong default dampening reuse_time value configured')
      assert_equal(bgp_af.default_dampening_suppress_time,
                   bgp_af.dampening_suppress_time,
                   'Wrong default dampening suppress_time value configured')
      assert_equal(bgp_af.default_dampening_max_suppress_time,
                   bgp_af.dampening_max_suppress_time,
                   'Wrong default dampening suppress_max_time value configured')
      assert_equal(bgp_af.default_dampening_routemap,
                   bgp_af.dampening_routemap,
                   'The default dampening routemap should configured')
    end

    bgp_af.destroy
  end

  ##
  ## distance
  ##
  def test_distance
    asn = '55'
    vrf = 'red'
    af = %w(ipv4 unicast)

    config_ios_xr_dependencies(asn) if platform == :ios_xr
    bgp_af = RouterBgpAF.new(asn, vrf, af)
    distance = [{ ebgp: 20, ibgp: 40, local: 60 },
                { ebgp:  bgp_af.default_distance_ebgp,
                  ibgp:  bgp_af.default_distance_ibgp,
                  local: bgp_af.default_distance_local },
                { ebgp:  bgp_af.default_distance_ebgp,
                  ibgp:  40,
                  local: 60 },
                { ebgp:  20,
                  ibgp:  bgp_af.default_distance_ibgp,
                  local: bgp_af.default_distance_local },
                { ebgp:  bgp_af.default_distance_ebgp,
                  ibgp:  bgp_af.default_distance_ibgp,
                  local: 60 },
               ]
    distance.each do |distancer|
      bgp_af.distance_set(distancer[:ebgp], distancer[:ibgp], distancer[:local])
      assert_equal(distancer[:ebgp], bgp_af.distance_ebgp)
      assert_equal(distancer[:ibgp], bgp_af.distance_ibgp)
      assert_equal(distancer[:local], bgp_af.distance_local)
    end
    bgp_af.destroy
  end

  ##
  ## default_metric
  ##
  def default_metric(asn, vrf, af)
    bgp_af = RouterBgpAF.new(asn, vrf, af)

    if platform == :ios_xr
      assert_nil(bgp_af.default_default_metric)
      assert_nil(bgp_af.default_metric)
      assert_raises(UnsupportedError) { bgp_af.default_metric = 50 }
      return
    end
    refute(bgp_af.default_default_metric,
           'default value for default default metric should be false')
    #
    # Set and verify
    #
    val = 50
    bgp_af.default_metric = val
    assert_equal(val, bgp_af.default_metric,
                 'Error: default metric value does not match set value')

    val = bgp_af.default_default_metric
    bgp_af.default_metric = val
    assert_equal(val, bgp_af.default_metric,
                 'Error: default metric value does not match default' \
                 'value')
  end

  def test_default_metric
    afs = [%w(ipv4 unicast), %w(ipv6 unicast)]
    afs.each do |af|
      config_ios_xr_dependencies('55') if platform == :ios_xr
      default_metric(55, 'red', af)
    end
  end

  ##
  ## inject_map
  ##
  def inject_map(asn, vrf, af)
    master = [%w(lax sfo),
              %w(lax sjc),
              %w(nyc sfo copy-attributes),
              %w(sjc nyc copy-attributes)]
    bgp_af = RouterBgpAF.new(asn, vrf, af)

    if platform == :ios_xr
      assert_nil(bgp_af.default_inject_map)
      assert_nil(bgp_af.inject_map)
      assert_raises(UnsupportedError) { bgp_af.inject_map = master }
      return
    end

    # Test1: both/import/export when no commands are present. Each target
    # option will be tested with and without evpn (6 separate types)
    should = master.clone
    inject_map_tester(bgp_af, should, 'Test 1')

    # Test 2: remove half of the entries
    should = [%w(lax sfo), %w(nyc sfo copy-attributes)]
    inject_map_tester(bgp_af, should, 'Test 2')

    # Test 3: restore the removed entries
    should = master.clone
    inject_map_tester(bgp_af, should, 'Test 3')

    # Test 4: 'default'
    should = bgp_af.default_inject_map
    inject_map_tester(bgp_af, should, 'Test 4')
  end

  def inject_map_tester(bgp_af, should, test_id)
    bgp_af.send('inject_map=', should)
    result = bgp_af.send('inject_map')
    assert_equal(should, result,
                 "#{test_id} : inject_map")
  end

  def test_inject_map
    # TODO: Fix it so we don't have to skip
    skip('Currently broken on IOS XR') if platform == :ios_xr

    afs = [%w(ipv4 unicast), %w(ipv6 unicast)]
    afs.each do |af|
      config_ios_xr_dependencies('55') if platform == :ios_xr
      inject_map(55, 'red', af)
    end
  end

  ##
  ## network
  ##

  def test_network
    vrfs = %w(default red)
    afs = [%w(ipv4 unicast), %w(ipv6 unicast)]
    vrfs.each do |vrf|
      afs.each do |af|
        dbg = sprintf('[VRF %s AF %s]', vrf, af.join('/'))
        config_ios_xr_dependencies(1)
        af_obj = RouterBgpAF.new(1, vrf, af)
        network_cmd(af_obj, dbg)

        af_obj.destroy
      end
    end
  end

  def network_cmd(af, dbg)
    if platform == :ios_xr
      %w(rtmap1 rtmap2 rtmap3 rtmap5 rtmap6 rtmap7).each do |policy|
        config("route-policy #{policy}", 'end')
      end
    end
    # Initial 'should' state
    if /ipv6/.match(dbg)
      master = [
        ['2000:123:38::/64', 'rtmap1'],
        ['2000:123:39::/64', 'rtmap2'],
        ['2000:123:40::/64', 'rtmap3'],
        ['2000:123:41::/64'],
        ['2000:123:42::/64', 'rtmap5'],
        ['2000:123:43::/64', 'rtmap6'],
        ['2000:123:44::/64'],
        ['2000:123:45::/64', 'rtmap7'],
      ]
    else
      master = [
        ['192.168.5.0/24', 'rtmap1'],
        ['192.168.6.0/24', 'rtmap2'],
        ['192.168.7.0/24', 'rtmap3'],
        ['192.168.8.0/24'],
        ['192.168.9.0/24', 'rtmap5'],
        ['192.168.10.0/24', 'rtmap6'],
        ['192.168.11.0/24'],
        ['192.168.12.0/24', 'rtmap7'],
      ]
    end

    # Test: all networks are set when current is empty.
    should = master.clone
    af.networks = should
    result = af.networks
    assert_equal(should.sort, result.sort,
                 "#{dbg} Test 1. From empty, to all networks")

    # Test: remove half of the networks
    should.shift(4)
    af.networks = should
    result = af.networks
    assert_equal(should.sort, result.sort,
                 "#{dbg} Test 2. Remove half of the networks")

    # Test: restore the removed networks
    should = master.clone
    af.networks = should
    result = af.networks
    assert_equal(should.sort, result.sort,
                 "#{dbg} Test 3. Restore the removed networks")

    # Test: Change route-maps on existing networks
    if platform == :ios_xr
      %w(rtmap1_55 rtmap2_55 rtmap3_55 rtmap5_55
         rtmap6_55 rtmap7_55).each do |policy|
        config("route-policy #{policy}", 'end')
      end
    end
    should = master.map { |network, rm| [network, rm.nil? ? nil : "#{rm}_55"] }
    af.networks = should
    result = af.networks
    assert_equal(should.sort, result.sort,
                 "#{dbg} Test 4. Change route-map on existing networks")

    # Test: 'default'
    should = af.default_networks
    af.networks = should
    result = af.networks
    assert_equal(should.sort, result.sort,
                 "#{dbg} Test 5. 'Default'")
    return unless platform == :ios_xr
    %w(rtmap1 rtmap2 rtmap3 rtmap5 rtmap6 rtmap7
       rtmap1_55 rtmap2_55 rtmap3_55
       rtmap5_55 rtmap6_55 rtmap7_55).each do |policy|
      config("no route-policy #{policy}")
    end
  end

  ##
  ## redistribute
  ##

  def test_redistribute
    vrfs = %w(default red)
    afs = [%w(ipv4 unicast), %w(ipv6 unicast)]
    vrfs.each do |vrf|
      afs.each do |af|
        dbg = sprintf('[VRF %s AF %s]', vrf, af.join('/'))
        config_ios_xr_dependencies(1) if platform == :ios_xr
        af = RouterBgpAF.new(1, vrf, af)
        redistribute_cmd(af, dbg)
        af.destroy
      end
    end
  end

  def redistribute_cmd(af, dbg)
    # rubocop:disable Style/WordArray
    # Initial 'should' state
    ospf = (dbg.include? 'ipv6') ? 'ospfv3 3' : 'ospf 3'
    if platform == :nexus
      master = [['direct',  'rm_direct'],
                ['lisp',    'rm_lisp'],
                ['static',  'rm_static'],
                ['eigrp 1', 'rm_eigrp'],
                ['isis 2',  'rm_isis'],
                [ospf,      'rm_ospf'],
                ['rip 4',   'rm_rip']]
    elsif platform == :ios_xr
      config('route-policy my_policy', 'end-policy')
      master = [['connected', 'my_policy'],
                ['eigrp 1',   'my_policy'],
                [ospf,        'my_policy'],
                ['static',    'my_policy']]
      master.push(['isis abc', 'my_policy']) if dbg.include? 'default'
    end
    # rubocop:enable Style/WordArray

    # Test: Add all protocols w/route-maps when no cmds are present
    should = master.clone
    af.redistribute = should
    result = af.redistribute
    assert_equal(should.sort, result.sort,
                 "#{dbg} Test 1. From empty, to all protocols")

    # Test: remove half of the protocols
    should.shift(4)
    af.redistribute = should
    result = af.redistribute
    assert_equal(should.sort, result.sort,
                 "#{dbg} Test 2. Remove half of the protocols")

    # Test: restore the removed protocols
    should = master.clone
    af.redistribute = should
    result = af.redistribute
    assert_equal(should.sort, result.sort,
                 "#{dbg} Test 3. Restore the removed protocols")

    # Test: Change route-maps on existing commands
    config('route-policy my_policy_2', 'end-policy')
    should = master.map { |prot_only, rm| [prot_only, "#{rm}_2"] }
    af.redistribute = should
    result = af.redistribute
    assert_equal(should.sort, result.sort,
                 "#{dbg} Test 4. Change route-maps on existing commands")

    # Test: 'default'
    should = af.default_redistribute
    af.redistribute = should
    result = af.redistribute
    assert_equal(should.sort, result.sort,
                 "#{dbg} Test 5. 'Default'")
    return unless platform == :ios_xr
    %w(my_policy my_policy_2).each do |policy|
      config("no route-policy #{policy}")
    end
  end

  ##
  ## common utilities
  ##
  def test_utils_delta_add_remove_depth_1
    # Note: AF context is not needed. This test is only validating the
    # delta_add_remove class method and does not test directly on the device.

    # Initial 'should' state
    should = ['1:1', '2:2', '3:3', '4:4', '5:5', '6:6']
    # rubocop:enable Style/WordArray

    # Test: Check delta when every protocol is specified and has a route-map.
    current = []
    expected = { add: should, remove: [] }
    result = Utils.delta_add_remove(should, current)
    assert_equal(expected, result, 'Test 1. delta mismatch')

    # Test: Check delta when should is the same as current.
    current = should.clone
    expected = { add: [], remove: [] }
    result = Utils.delta_add_remove(should, current)
    assert_equal(expected, result, 'Test 2. delta mismatch')

    # Test: Move half the 'current' entries to 'should'. Check delta.
    should = current.shift(4)
    expected = { add: should, remove: current }
    result = Utils.delta_add_remove(should, current)
    assert_equal(expected, result, 'Test 3. delta mismatch')

    # Test: Remove the route-maps from the current list. Check delta.
    #       Note: The :remove list should be empty since this is just
    #       an update of the route-map.
    should = current.map { |prot_only, _route_map| [prot_only] }
    expected = { add: should, remove: [] }
    result = Utils.delta_add_remove(should, current)
    assert_equal(expected, result, 'Test 4. delta mismatch')

    # Test: Check empty inputs
    should = []
    current = []
    expected = { add: [], remove: [] }
    result = Utils.delta_add_remove(should, current)
    assert_equal(expected, result, 'Test 5. delta mismatch')
  end

  def test_utils_delta_add_remove
    # Note: AF context is not needed. This test is only validating the
    # delta_add_remove class method and does not test directly on the device.

    # rubocop:disable Style/WordArray
    # Initial 'should' state
    should = [['direct',  'rm_direct'],
              ['lisp',    'rm_lisp'],
              ['static',  'rm_static'],
              ['eigrp 1', 'rm_eigrp'],
              ['isis 2',  'rm_isis'],
              ['ospf 3',  'rm_ospf'],
              ['rip 4',   'rm_rip']]
    # rubocop:enable Style/WordArray

    # Test: Check delta when every protocol is specified and has a route-map.
    current = []
    expected = { add: should, remove: [] }
    result = Utils.delta_add_remove(should, current)
    assert_equal(expected, result, 'Test 1. delta mismatch')

    # Test: Check delta when should is the same as current.
    current = should.clone
    expected = { add: [], remove: [] }
    result = Utils.delta_add_remove(should, current)
    assert_equal(expected, result, 'Test 2. delta mismatch')

    # Test: Move half the 'current' entries to 'should'. Check delta.
    should = current.shift(4)
    expected = { add: should, remove: current }
    result = Utils.delta_add_remove(should, current)
    assert_equal(expected, result, 'Test 3. delta mismatch')

    # Test: Remove the route-maps from the current list. Check delta.
    #       Note: The :remove list should be empty since this is just
    #       an update of the route-map.
    should = current.map { |prot_only, _route_map| [prot_only] }
    expected = { add: should, remove: [] }
    result = Utils.delta_add_remove(should, current)
    assert_equal(expected, result, 'Test 4. delta mismatch')

    # Test: Check empty inputs
    should = []
    current = []
    expected = { add: [], remove: [] }
    result = Utils.delta_add_remove(should, current)
    assert_equal(expected, result, 'Test 5. delta mismatch')
  end

  ##
  ## suppress_inactive
  ##
  def suppress_inactive(asn, vrf, af)
    bgp_af = RouterBgpAF.new(asn, vrf, af)

    if platform == :ios_xr
      assert_nil(bgp_af.default_suppress_inactive)
      assert_nil(bgp_af.suppress_inactive)
      assert_raises(UnsupportedError) { bgp_af.suppress_inactive = false }
      return
    end

    #
    # Set and verify
    #
    val = false
    bgp_af.suppress_inactive = val
    refute(bgp_af.suppress_inactive,
           'Error: suppress inactive value does not match set value')

    val = true
    bgp_af.suppress_inactive = val
    assert(bgp_af.suppress_inactive,
           'Error: suppress inactive value does not match set value')

    val = bgp_af.default_suppress_inactive
    bgp_af.suppress_inactive = val
    refute(bgp_af.suppress_inactive,
           'Error: suppress inactive value does not match default value')
  end

  def test_suppress_inactive
    afs = [%w(ipv4 unicast), %w(ipv6 unicast)]
    afs.each do |af|
      config_ios_xr_dependencies('55') if platform == :ios_xr
      suppress_inactive(55, 'red', af)
    end
  end

  ##
  ## table_map
  ##
  def table_map(asn, vrf, af)
    bgp_af = RouterBgpAF.new(asn, vrf, af)

    #
    # Set and verify
    #
    val = 'sjc'
    bgp_af.table_map_set(val)
    assert_equal(val, bgp_af.table_map,
                 'Error: default metric value does not match set value')

    val = bgp_af.default_table_map
    bgp_af.table_map_set(val)
    assert_equal(val, bgp_af.table_map,
                 'Error: default metric value does not match default' \
                 'value')

    val = false
    bgp_af.table_map_set('sjc', val)
    refute(bgp_af.table_map_filter,
           'Error: suppress inactive value does not match set value')

    val = true
    bgp_af.table_map_set('sjc', val)
    assert(bgp_af.table_map_filter,
           'Error: suppress inactive value does not match set value')

    val = bgp_af.default_table_map_filter
    bgp_af.table_map_set('sjc', val)
    refute(bgp_af.table_map_filter,
           'Error: suppress inactive value does not match default value')
  end

  def test_table_map
    afs = [%w(ipv4 unicast), %w(ipv6 unicast)]
    afs.each do |af|
      config_ios_xr_dependencies('55') if platform == :ios_xr
      table_map(55, 'red', af)
    end
  end
end
