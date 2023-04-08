#!/usr/bin/perl -w
#
# Program: LDAP Statistics Collector <ldap-gather.pl>
#
# Credit to original author > Matty < matty91 @ gmail dot com >
#
# Purpose:
#   ldap-gather is a Perl script designed to extract various performance
#   metrics from an OpenLDAP server
#
# Usage:
#   Please see the usage() sub-routine.
#
# Installation:
#   Install Net::LDAP and copy the Perl script to a suitable location
#
# Examples:
#     $ ldap-gather.pl -H "example.com" -p "636" -D "cn=ldap,dc=example,dc=com" -w "1234567890" -z
#     $ ldap-gather.pl -H "example.com" -p "389" -D "cn=ldap,dc=example,dc=com" -w "1234567890" -Z

use Net::LDAPS;
use Getopt::Std;

#######################################
# Functions
#######################################

# Create a universal usage routine to call if problems are detected
sub usage () {
        printf("Usage: ldap-gather.pl [ -h ] [ -H 'server' ] [ -p 'port' ] [ -D 'bind_dn'] [ -w 'bind_pw' ]\n");
        printf("  -h         : Print help and exit\n");
        printf("  -H server  : Hostname to connect to\n");
        printf("  -p port    : TCP port to connect to\n");
        printf("  -D bind_dn : Bind dn for server\n");
        printf("  -w bind_pw : Password for bind dn\n");
        printf("  -z         : Connect using ssl. Mutually exclusive with -Z.\n");
        printf("  -Z         : Connect using start_tls. Mutually exclusive with -z.\n");
        exit(2);
}

# Borrowed from code written by Quanah Gibson-Mount
sub getMonitorDesc {
        my $dn = $_[0];
        my $attr = $_[1];
        my $ldapstruct = $_[2];

        if (!$attr) {
                 $attr="description";
        }
        my $searchResults = $ldapstruct->search(base => "$dn",
                            scope => 'base',
                            filter => 'objectClass=*',
                            attrs => ["$attr"],);

        if ($searchResults->code) {
            printf ("CODE: ");
            printf $searchResults->code;
            printf (". ");
            printf ("ERROR: ");
            printf $searchResults->error;
            printf (".\n");
            exit $searchResults->code; }

        my $entry = $searchResults->pop_entry() if $searchResults->count() == 1;

        $entry->get_value("$attr");
}

#######################################
#  Global variables get set to 0 here #
#######################################
my $timestamp = time();
my $ldap;


###################################
# Get the arguments from the user #
###################################
%options=();
getopts("hH:p:D:w:zZ",\%options);

my $port = $options{p} || 389;
my $host = $options{H} || "localhost";
my $bind_dn = $options{D} || usage();
my $bind_pw = $options{w} || usage();

if (defined $options{h} ) {
        usage();
}

if (defined $options{z} && defined $options{Z} ) {
        usage();
}

###################################################
# Create new connection and bind to the server    #
###################################################
if (defined $options{z} ) {
        $ldap = new Net::LDAPS($host, port=> $port) or die "Failed to create socket to $host:$port: Perl error:  $@";

        $ldap->bind( "$bind_dn",
           "base"     => "",
           "password"     => "$bind_pw",
           "version"  => 3
        ) or die "Failed to bind to LDAP server: Perl error: $@"; }
if (defined $options{Z} ) {
        $ldap = new Net::LDAP($host, port=> $port) or die "Failed to create socket to $host:$port: Perl error:  $@";
        $ldap->start_tls();
        $ldap->bind( "$bind_dn",
           "base"     => "",
           "password"     => "$bind_pw",
           "version"  => 3
        ) or die "Failed to bind to LDAP server: Perl error: $@"; }

###############################################
# Collect the statistics from the server      #
###############################################
my $total_connections = getMonitorDesc("cn=Total,cn=Connections,cn=Monitor","monitorCounter",$ldap);
my $current_connections = getMonitorDesc("cn=Current,cn=Connections,cn=Monitor","monitorCounter",$ldap);
my $bind_operations_initiated = getMonitorDesc("cn=Bind,cn=Operations,cn=Monitor","monitorOpInitiated",$ldap);
my $bind_operations_completed = getMonitorDesc("cn=Bind,cn=Operations,cn=Monitor","monitorOpCompleted",$ldap);
my $unbind_operations_initiated = getMonitorDesc("cn=Unbind,cn=Operations,cn=Monitor","monitorOpInitiated",$ldap);
my $unbind_operations_completed = getMonitorDesc("cn=Unbind,cn=Operations,cn=Monitor","monitorOpCompleted",$ldap);
my $search_operations_initiated = getMonitorDesc("cn=Search,cn=Operations,cn=Monitor","monitorOpInitiated",$ldap);
my $search_operations_completed = getMonitorDesc("cn=Search,cn=Operations,cn=Monitor","monitorOpCompleted",$ldap);
my $compare_operations_initiated = getMonitorDesc("cn=Compare,cn=Operations,cn=Monitor","monitorOpInitiated",$ldap);
my $compare_operations_completed = getMonitorDesc("cn=Compare,cn=Operations,cn=Monitor","monitorOpCompleted",$ldap);
my $modify_operations_initiated = getMonitorDesc("cn=Modify,cn=Operations,cn=Monitor","monitorOpInitiated",$ldap);
my $modify_operations_completed = getMonitorDesc("cn=Modify,cn=Operations,cn=Monitor","monitorOpCompleted",$ldap);
my $modrdn_operations_initiated = getMonitorDesc("cn=Modrdn,cn=Operations,cn=Monitor","monitorOpInitiated",$ldap);
my $modrdn_operations_completed = getMonitorDesc("cn=Modrdn,cn=Operations,cn=Monitor","monitorOpCompleted",$ldap);
my $add_operations_initiated = getMonitorDesc("cn=Add,cn=Operations,cn=Monitor","monitorOpInitiated",$ldap);
my $add_operations_completed = getMonitorDesc("cn=Add,cn=Operations,cn=Monitor","monitorOpCompleted",$ldap);
my $delete_operations_initiated = getMonitorDesc("cn=Delete,cn=Operations,cn=Monitor","monitorOpInitiated",$ldap);
my $delete_operations_completed = getMonitorDesc("cn=Delete,cn=Operations,cn=Monitor","monitorOpCompleted",$ldap);
my $abandon_operations_initiated = getMonitorDesc("cn=Abandon,cn=Operations,cn=Monitor","monitorOpInitiated",$ldap);
my $abandon_operations_completed = getMonitorDesc("cn=Abandon,cn=Operations,cn=Monitor","monitorOpCompleted",$ldap);
my $extended_operations_initiated = getMonitorDesc("cn=Extended,cn=Operations,cn=Monitor","monitorOpInitiated",$ldap);
my $extended_operations_completed = getMonitorDesc("cn=Extended,cn=Operations,cn=Monitor","monitorOpCompleted",$ldap);
my $bytes_statistics = getMonitorDesc("cn=Bytes,cn=Statistics,cn=Monitor","monitorCounter",$ldap);
my $pdu_statistics = getMonitorDesc("cn=PDU,cn=Statistics,cn=Monitor","monitorCounter",$ldap);
my $entries_statistics = getMonitorDesc("cn=Entries,cn=Statistics,cn=Monitor","monitorCounter",$ldap);
my $referrals_statistics = getMonitorDesc("cn=Referrals,cn=Statistics,cn=Monitor","monitorCounter",$ldap);
my $max_threads = getMonitorDesc("cn=Max,cn=Threads,cn=Monitor","monitoredInfo",$ldap);
my $max_pending_threads = getMonitorDesc("cn=Max Pending,cn=Threads,cn=Monitor","monitoredInfo",$ldap);
my $open_threads = getMonitorDesc("cn=Open,cn=Threads,cn=Monitor","monitoredInfo",$ldap);
my $starting_threads = getMonitorDesc("cn=Starting,cn=Threads,cn=Monitor","monitoredInfo",$ldap);
my $active_threads = getMonitorDesc("cn=Active,cn=Threads,cn=Monitor","monitoredInfo",$ldap);
my $pending_threads = getMonitorDesc("cn=Pending,cn=Threads,cn=Monitor","monitoredInfo",$ldap);
my $backload_threads = getMonitorDesc("cn=Backload,cn=Threads,cn=Monitor","monitoredInfo",$ldap);
my $uptime_time = getMonitorDesc("cn=Uptime,cn=Time,cn=Monitor","monitoredInfo",$ldap);
my $read_waiters = getMonitorDesc("cn=Read,cn=Waiters,cn=Monitor","monitorCounter",$ldap);
my $write_waiters = getMonitorDesc("cn=Write,cn=Waiters,cn=Monitor","monitorCounter",$ldap);

###############################################
# Exit and echo the values
###############################################
print STDOUT "OK.|";
print STDOUT "Total_Connections=$total_connections;;; ";
print STDOUT "Current_Connections=$current_connections;;; ";
print STDOUT "Bind_Operations_Initiated=$bind_operations_initiated;;; ";
print STDOUT "Bind_Operations_Completed=$bind_operations_completed;;; ";
print STDOUT "Unbind_Operations_Initiated=$unbind_operations_initiated;;; ";
print STDOUT "Unbind_Operations_Completed=$unbind_operations_completed;;; ";
print STDOUT "Search_Operations_Initiated=$search_operations_initiated;;; ";
print STDOUT "Search_Operations_Completed=$search_operations_completed;;; ";
print STDOUT "Compare_Operations_Initiated=$compare_operations_initiated;;; ";
print STDOUT "Compare_Operations_Completed=$compare_operations_completed;;; ";
print STDOUT "Modify_Operations_Initiated=$modify_operations_initiated;;; ";
print STDOUT "Modify_Operations_Completed=$modify_operations_completed;;; ";
print STDOUT "Modrdn_Operations_Initiated=$modrdn_operations_initiated;;; ";
print STDOUT "Modrdn_Operations_Completed=$modrdn_operations_completed;;; ";
print STDOUT "Add_Operations_Initiated=$add_operations_initiated;;; ";
print STDOUT "Add_Operations_Completed=$add_operations_completed;;; ";
print STDOUT "Delete_Operations_Initiated=$delete_operations_initiated;;; ";
print STDOUT "Delete_Operations_Completed=$delete_operations_completed;;; ";
print STDOUT "Abandon_Operations_Initiated=$abandon_operations_initiated;;; ";
print STDOUT "Abandon_Operations_Completed=$abandon_operations_completed;;; ";
print STDOUT "Extended_Operations_Initiated=$extended_operations_initiated;;; ";
print STDOUT "Extended_Operations_Completed=$extended_operations_completed;;; ";
print STDOUT "Bytes_Statistics=$bytes_statistics;;; ";
print STDOUT "Pdu_Statistics=$pdu_statistics;;; ";
print STDOUT "Entries_Statistics=$entries_statistics;;; ";
print STDOUT "Referrals_Statistics=$referrals_statistics;;; ";
print STDOUT "Max_Threads=$max_threads;;; ";
print STDOUT "Max_Pending_Threads=$max_pending_threads;;; ";
print STDOUT "Open_Threads=$open_threads;;; ";
print STDOUT "Starting_Threads=$starting_threads;;; ";
print STDOUT "Active_Threads=$active_threads;;; ";
print STDOUT "Pending_Threads=$pending_threads;;; ";
print STDOUT "Backload_Threads=$backload_threads;;; ";
print STDOUT "Uptime_Time=$uptime_time;;; ";
print STDOUT "Read_Waiters=$read_waiters;;; ";
print STDOUT "Write_Waiters=$write_waiters;;; ";
print STDOUT "\n";
$ldap->unbind;
exit 0;
