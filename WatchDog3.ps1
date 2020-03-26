###########################################################
<# 
## Instructions ##

# Setup
- [stop neo4j service if running]
- uncomment following in neo4j.conf and save change
dbms.security.auth_enabled=false
[will disable auth for Localhost only]
- start neo4j service
- load watchdog.ps1

# Basic usage
-Single Group:
$Data = Datadog <groupname>

-Default Group List:
$Data = WatchDog <domainname>

-TotalImpact
$Data | TotalImpact

-Text Report:
$Data | ReportDog 

##
#>

#################################################### Vars

## Group List [Customize if needed]
$GroupList = @(
    <###############| NAME                                       |SID [regex]             #>
    <######################################################################################>
    [PSCustomObject]@{Name='Account Operators'                   ;SID='S-1-5-32-548'      }
    [PSCustomObject]@{Name='Administrators'                      ;SID='S-1-5-32-544'      }
    [PSCustomObject]@{Name='Allowed RODC Password Replication'   ;SID='^S-1-5-21-.*-571$' }
    [PSCustomObject]@{Name='Backup Operators'                    ;SID='S-1-5-32-551'      }
    [PSCustomObject]@{Name='Certificate Service DCOM Access'     ;SID='S-1-5-32-574'      }
    [PSCustomObject]@{Name='Cert Publishers'                     ;SID='^S-1-5-21-.*-517$' }
    [PSCustomObject]@{Name='Distributed DCOM Users'              ;SID='S-1-5-32-562'      }
    [PSCustomObject]@{Name='Domain Admins'                       ;SID='^S-1-5-21-.*-512$' }
    [PSCustomObject]@{Name='Domain Controllers'                  ;SID='^S-1-5-21-.*-516$' }
    [PSCustomObject]@{Name='Enterprise Admins'                   ;SID='S-1-5-21-.*-519'      }#HeadOnly
    [PSCustomObject]@{Name='Event Log Readers'                   ;SID='S-1-5-32-573'      }
    [PSCustomObject]@{Name='Group Policy Creators Owners'        ;SID='^S-1-5-21-.*-520$' }
    [PSCustomObject]@{Name='Hyper-V Admistrators'                ;SID='S-1-5-32-578'      }
    [PSCustomObject]@{Name='Pre-Windows 2000 compatible Access'  ;SID='S-1-5-32-554'      }
    [PSCustomObject]@{Name='Print Operators'                     ;SID='S-1-5-32-550'      }
    [PSCustomObject]@{Name='Protected Users'                     ;SID='^S-1-5-21-.*-525$' }
    [PSCustomObject]@{Name='Remote Desktop Users'                ;SID='S-1-5-32-555'      }
    [PSCustomObject]@{Name='Schema Admins'                       ;SID='S-1-5-21-.*-518'      }#HeadOnly
    [PSCustomObject]@{Name='Server Operators'                    ;SID='S-1-5-32-549'      }
    [PSCustomObject]@{Name='Incoming Forest Trust Builders'      ;SID='S-1-5-32-557'      }#HeadOnly
    [PSCustomObject]@{Name='Cryptographic Operators'             ;SID='S-1-5-32-569'      }
    [PSCustomObject]@{Name='Key Admins'                          ;SID='^S-1-5-21-.*-526$' }#HeadOnly
    [PSCustomObject]@{Name='Enterprise Key Admins'               ;SID='^S-1-5-21-.*-527$' }#HeadOnly
    )###################### Add more SIDS if needed... ####################################
    


Enum ScanType{
    Mini
    MiniX
    Mimi
    MimiX
    Standard
    StandardX
    Advanced
    AdvancedX
    Extreme
    ExtremeX
    Custom
    }

####################################################### DataDog Obj

# DataDog Object format
Class DataDog{
    [String]$Group
    [String]$SID
    [String]$Description
    [int]$DirectMbrCount
    [int]$NestedMbrCount
    [int]$PathCount
    [int]$UserPathCount
    [Array]$NodeWeight
    [String[]]$Cypher   
    }

###########################################################

<#
.Synopsis
   Time
.DESCRIPTION
   Time
.EXAMPLE
   Time
#>
function Time{Get-Date -F hh:mm:ss}

###########################################################

<#
.Synopsis
   Invoke Cypher
.DESCRIPTION
   Post Cypher Query to REST API
   Cypher $Query [$Params] [-expand <prop,prop>]
   Post Cypher Query to BH
.EXAMPLE
    $query="MATCH (n:User) RETURN n"
    Cypher $Query -Expand $Null
#>
function Invoke-Cypher{
    [CmdletBinding()]
    [Alias('Cypher')]
    Param(
        # Cypher Query
        [Parameter(Mandatory=1)][string]$Query,
        # Query Params [optional]
        [Parameter(Mandatory=0)][Hashtable]$Params,
        # Expand Props [Default to .data.data /  Use -Expand $Null for raw objects]
        [Parameter(Mandatory=0)][Alias('x')][String[]]$Expand=@('data','data')
        )
    # Uri 
    $Uri = "http://localhost:7474/db/data/cypher"
    # Header
    $Header=@{'Accept'='application/json; charset=UTF-8';'Content-Type'='application/json'}
    # Query [spec chars to unicode]
    $Query=$($Query.ToCharArray()|%{$x=[Byte][Char]"$_";if($x-gt191-AND$x-le255){'\u{0:X4}'-f$x}else{$_}})-join''
    # Body
    if($Params){$Body = @{params=$Params; query=$Query}|Convertto-Json}
    else{$Body = @{query=$Query}|Convertto-Json}
    # Call
    #Write-Verbose "[+][$(Time)] Querying Database..."
    Write-Verbose "[+][$(Time)] $Query" <#Ckeck $Body if strange chars#>
    $Reply = Try{Invoke-RestMethod -Uri $Uri -Method Post -Headers $Header -Body $Body -verbose:$false}Catch{$Oops = $Error[0].ErrorDetails.Message}
    # Format obj
    if($Oops){Write-Warning "$((ConvertFrom-Json $Oops).message)";Return}
    if($Expand){$Expand | %{$Reply = $Reply.$_}} 
    # Output Reply
    if($Reply){Return $Reply}
    }
#End

###########################################################

<#
.Synopsis
   BloodHound DB Info
.DESCRIPTION
   Get BloodHound DB node and edge count
.EXAMPLE
   DBInfo
#>
function Get-BloodHoundDBInfo{
    [Alias('DBInfo')]
    Param()
    Write-Verbose "[+][$(Time)] Fetching DB Info..."
    [PSCustomObject]@{
        Domains   = (Cypher 'MATCH (x:Domain) RETURN COUNT(x)' -expand Data)[0]
        Nodes     = (Cypher 'MATCH (x) RETURN COUNT(x)' -expand Data)[0] 
        Users     = (Cypher 'MATCH (x:User) WHERE EXISTS(x.domain) RETURN COUNT(x)' -expand Data)[0]
        Computers = (Cypher 'MATCH (x:Computer) RETURN COUNT(x)' -expand Data)[0]
        Groups    = (Cypher 'MATCH (x:Group) RETURN COUNT(x)' -expand Data)[0]
        OUs       = (Cypher 'MATCH (x:OU) RETURN COUNT(x)' -expand Data)[0]
        GPOs      = (Cypher 'MATCH (x:GPO) RETURN COUNT(x)' -expand Data)[0]
        Edges     = (Cypher 'MATCH (x)-[r]->() RETURN COUNT(r)' -expand Data)[0]
        ACLs      = (Cypher "MATCH x=(s)-[r]->(t) WHERE r.isacl=True RETURN COUNT(x)" -Expand Data)[0]
        Sessions  = (Cypher "MATCH p=(s:Computer)-[r:HasSession]->(t:User) RETURN COUNT(r)" -expand Data)[0]
        }}
#####End

###########################################################

<#
.Synopsis
   BloodHound DataDog
.DESCRIPTION
   BloodHound node metrics on user shortest path to specified target group
.EXAMPLE
   DataDog 'DOMAIN ADMINS@DOMAIN.LOCAL','BACKUP OPERATORS@DOMAIN.LOCAL'
#>
Function Invoke-DataDog{
    [Alias('DataDog')]
    [OutputType([Datadog])]
    Param(
        # Name of the Group to Scan
        [Parameter(Mandatory=1,ValueFromPipeline=$true)][Alias('Group')][String[]]$Name,
        # Limit number of returned path
        [Parameter(Mandatory=0)][Int]$Limit=1000,
        # Scan Type
        [Parameter(Mandatory=0)][ScanType]$ScanType="Advanced",
        # Switch to All Shortest Paths
        [Parameter(Mandatory=0)][Switch]$AllShortest,
        # Switch Quick [less accurate]
        [Parameter(Mandatory=0)][Switch]$Quick,
        # Specify user origin
        [Parameter(Mandatory=0)][String]$UserDomain
        )
    Begin{
        $EdgeList = Switch("$ScanType".ToUpper()){
            MINI     {":MemberOf|AdminTo|HasSIDHistory"}
            MINIX    {":MemberOf|AdminTo|HasSIDHistory|CanRDP|CanPSRemote|ExecuteDCOM"}
            MIMI     {":MemberOf|HasSession|AdminTo|HasSIDHistory"}
            MIMIX    {":MemberOf|HasSession|AdminTo|HasSIDHistory|CanRDP|CanPSRemote|ExecuteDCOM"}
            STANDARD {":MemberOf|HasSession|AdminTo|AllExtendedRights|AddMember|ForceChangePassword|GenericAll|GenericWrite|Owns|WriteDacl|WriteOwner|ReadLAPSPassword|ReadGMSAPassword"}
            STANTARDX{":MemberOf|HasSession|AdminTo|AllExtendedRights|AddMember|ForceChangePassword|GenericAll|GenericWrite|Owns|WriteDacl|WriteOwner|ReadLAPSPassword|ReadGMSAPassword|CanRDP|CanPSRemote|ExecuteDCOM"}
            ADVANCED {":MemberOf|HasSession|AdminTo|AllExtendedRights|AddMember|ForceChangePassword|GenericAll|GenericWrite|Owns|WriteDacl|WriteOwner|ReadLAPSPassword|ReadGMSAPassword|AllowedToDelegate|AddAllowedToAct|AllowedToAct|SQLAdmin|HasSIDHistory"}
            ADVANCEDX{":MemberOf|HasSession|AdminTo|AllExtendedRights|AddMember|ForceChangePassword|GenericAll|GenericWrite|Owns|WriteDacl|WriteOwner|ReadLAPSPassword|ReadGMSAPassword|AllowedToDelegate|AddAllowedToAct|AllowedToAct|SQLAdmin|HasSIDHistory|CanRDP|CanPSRemote|ExecuteDCOM"}
            EXTREME  {":MemberOf|HasSession|AdminTo|AllExtendedRights|AddMember|ForceChangePassword|GenericAll|GenericWrite|Owns|WriteDacl|WriteOwner|ReadLAPSPassword|ReadGMSAPassword|AllowedToDelegate|AddAllowedToAct|AllowedToAct|SQLAdmin|HasSIDHistory|Contains|GpLink"}
            EXTREMEX {""}
            CUSTOM   {":MemberOf|HasSession|AdminTo|AllExtendedRights|AddMember|ForceChangePassword|GenericAll|GenericWrite|Owns|WriteDacl|WriteOwner|ReadLAPSPassword|ExecuteDCOM|AllowedToDelegate|AddAllowedToAct|AllowedToAct"}
            }
        # if All Shortest Path
        if($AllShortest){$q='allShortestPaths'}Else{$q='shortestPath'}
        # If Quick [No Order]
        if($Quick){$order=$Null}Else{$order='ORDER BY LENGTH(p) '}
        }
    Process{
        Foreach($Obj in $Name){
            # Get Group
            Write-Verbose "[?][$(Time)] Querying Group by Name"
            $Grp = Cypher "MATCH (g:Group {name:'$Obj'}) RETURN g" | select Name,objectid,description
            # If Group not found
            if(-NOT $Grp.name){
                Write-Warning "[!][$(Time)] OBJECT NOT FOUND: $Obj`r`n"
                }
            # If Group found
            else{
                # Name & stuff
                $SD   = $Grp.objectid
                $Nme  = $Grp.Name
                $Desc = $Grp.Description
                #if($UserDomain){$WhereDom=" WHERE m.name=~'@$($Grp.Name.split('@')[1])'"}
                if($UserDomain){$WhereDom=" WHERE m.name ENDS WITH '@$($UserDomain.ToUpper())'"}
                Write-Verbose "[*][$(Time)] $Nme"
                # Direct Members
                Write-Verbose "[.][$(Time)] Querying Direct Member Count"
                $Cypher1   = "MATCH (m:User)$WhereDom MATCH p=shortestPath((m)-[r:MemberOf*1]->(n:Group {name:'$NmE'})) RETURN COUNT(m)"
                $DirectMbr = (Cypher $Cypher1 -expand data)|Select -first 1
                Write-Verbose "[.][$(Time)] > Direct Member: $DirectMbr"
                # Unrolled Members
                Write-Verbose "[.][$(Time)] Querying Nested Member Count"
                $cypher2   = "MATCH (m:User)$WhereDom MATCH p=shortestPath((m)-[r:MemberOf*1..]->(n:Group {name:'$NmE'})) RETURN COUNT(m)"
                $UnrollMbr =(Cypher $Cypher2 -expand data)|Select -first 1
                Write-Verbose "[.][$(Time)] > Nested Member: $($UnrollMbr-$DirectMbr)"
                # Shortest Path
                $Cypher3   = "MATCH (m:User)$WhereDom MATCH p=$q((m)-[r$EdgeList*1..]->(n:Group {name:'$NmE'})) RETURN p ${Order}LIMIT $Limit"
                Write-Verbose "[.][$(Time)] Querying User Shortest Paths"
                $RawData  = Cypher $Cypher3 -expand data
                # User Path Count
                $PathCount = $RawData.count
                $UserCount = ($RawData.start|sort -unique).count
                Write-Verbose "[.][$(Time)] > UserPathCount: $UserCount"
                # Node Weight
                Write-Verbose "[.][$(Time)] Grouping Nodes"
                $AllNodeU = $RawData.nodes | Group  | Select name,count
                Write-Verbose "[.][$(Time)] Mesuring Weight"
                $NodeWeight = @(Foreach($x in $AllNodeU){
                    #  Name
                    $Obj=irm $x.Name -Verbose:$false
                    # Dist
                    $Path = $RawData | ? {$_.nodes -match $x.name} | select -first 1
                    $Step = $Path.Nodes.Count-1
                    if($Path){while($Path.Nodes[$Step] -ne $x.name -AND $Step -gt 1){$Step-=1}}
                    # Calc Weight
                    $W=$X|select -expand Count
                    # Out
                    [PScustomObject]@{
                        Type     = $Obj.metadata.labels[0]
                        Name     = $Obj.data.name
                        Distance = ($Path.Nodes.Count)-$Step-1
                        Weight   = $W
                        Impact   = [Math]::Round($W/$RawData.Count*100,1)
                        }
                    })

                # Cypher
                Write-Verbose "[.][$(Time)] Storing Cypher"
                $Cypher = @(
                    $Cypher1.Replace('COUNT(m)','p')
                    $Cypher1.Replace('COUNT(m)','{Type: "Direct", Name: m.name, SID: m.objectid} as obj')
                    $Cypher2.Replace('COUNT(m)','p')
                    $Cypher2.Replace('COUNT(m)','{Type: "Nested", Name: m.name, SID: m.objectid} as obj')
                    $Cypher3
                    $Cypher3.Replace("RETURN p ${Order}LIMIT $limit",'RETURN {Type: "Path", Name: m.name, SID: m.objectid} as obj')
                    )    
                # Output DataDog Obj
                Write-Verbose "[+][$(Time)] Returning Object...`r`n"
                [DataDog]@{
                    Group         = $Nme
                    SID           = $SD
                    Description   = $Desc
                    DirectMbrCount= $DirectMbr
                    NestedMbrCount= $UnrollMbr - $DirectMbr
                    PathCount     = $PathCount
                    UserPathCount = $UserCount
                    NodeWeight    = $NodeWeight
                    Cypher        = $Cypher
                    }}}}
    End{}###########
    }
#End

###########################################################

<#
.Synopsis
   BloodHound Watchdog
.DESCRIPTION
   Collect Path Data from default group for specified domain
.EXAMPLE
   WatchDog domain.local
#>
Function Invoke-WatchDog{
    [Alias('WatchDog')]
    [OutputType([Datadog])]
    Param(
        # Name of the domain to scan
        [Parameter()][String]$Domain,
        # Add extra Group Names
        [Parameter()][String[]]$ExtraGroup,
        # Limit Number of returned paths
        [Parameter(Mandatory=0)][Int]$Limit=1000,
        # Scan Type
        [Parameter()][ScanType]$ScanType='Advanced',
        # Switch to All Shortest Paths
        [Parameter(Mandatory=0)][Switch]$AllShortest,
        # Switch Quick [less accurate]
        [Parameter(Mandatory=0)][Switch]$Quick,
        # Specify user origin
        [Parameter(Mandatory=0)][String]$UserDomain
        )
    # Domain to upper
    $Domain = $Domain.ToUpper()
    ## foreach in list ##
    foreach($Obj in $GroupList){
        # Get Group
        $ObjID = if($Obj.SID -match '^S-1-5-32-'){"$Domain"+"-$($Obj.SID)"}else{"$($Obj.SID)"}
        Write-Verbose "[?][$(Time)] Searching Name by SID"
        $Grp = Cypher "MATCH (g:Group {domain:'$Domain'}) WHERE g.objectid =~ '(?i)$ObjID' RETURN g" | select Name,objectid,description
        # If Group not found
        if(-NOT $Grp.objectid){
            Write-Warning  "[!][$(Time)] OBJECT NOT FOUND: $($Obj.Name)`r`n"
            }
        # If Group found
        else{DataDog $Grp.name -ScanType $ScanType -AllShortest:$AllShortest -Quick:$Quick -Limit $Limit -UserDomain $UserDomain}
        }
    ## If Extra ##
    if($ExtraGroup){$ExtraGroup|DataDog -ScanType $ScanType -AllShortest:$AllShortest -Quick:$Quick -Limit $Limit -UserDomain $UserDomain}     
    }
#End

###########################################################

<#
.Synopsis
   Calc Ttl Impact - INTERNAL
.DESCRIPTION
   Calculate Total Impact from Datadog Object Collection
.EXAMPLE
   $Data | TotalImpact
#>
function Measure-TotalImpact{
    [Alias('TotalImpact')]
    Param(
        # Datadog Objects [Piped from DataDog/WatchDog]
        [Parameter(Mandatory=1,ValueFromPipeline=1)][Datadog[]]$Data,
        # Filter on Node Type [optional]
        [ValidateSet('User','Group','Computer','GPO','OU')]
        [Parameter(Mandatory=0)][Alias('Filter')][String]$Type,
        # Limit to Top X [optional]
        [Parameter(Mandatory=0)][Alias('Limit')][Int]$Top
        ) 
    Begin{[Collections.ArrayList]$Collect=@()}
    Process{foreach($Obj in ($data)){$Null=$Collect.add($Obj)}}
    End{
        # Total Path Count
        $TtlPC=($Collect|measure -prop PathCount -sum).sum
        # Total Unique User Count
        $TtlUC= (($Collect.NodeWeight|? Type -eq User).name| Sort -Unique ).count
        # Total Object
        $Res = $Collect.NodeWeight | ? Distance -ne 0 | Group Name |%{
            $TtlW = ($_.Group|Measure-object -Property Weight -sum).sum
            [PSCustomObject]@{
                Type= $_.Group[0].type
                Name= $_.Name
                Hit=$_|Select -expand Count
                Weight=$TtlW
                Impact=[Math]::Round($TtlW/$TtlPC*100,1)
                }
            }
        $res = $res | Sort Impact -Descending
        if($Type){$Res = $Res | ? type -eq $Type}
        if($Top){$res = $res | select -first $top}
        $res
        }
    }
#End

###########################################################

<#
.Synopsis
   WatchDog Report
.DESCRIPTION
   DataDog/WatchDog to readable text report
.EXAMPLE
   $Data | ReportDog
   Will generate report out of Datadog objects
   $Data holds result of WatchDog/DataDog Command
#>
Function Invoke-ReportDog{
    [Alias('ReportDog')]
    Param(
        [Parameter(ValueFromPipeline=1)][DataDog[]]$Data,
        [Parameter()][String]$File,
        [Parameter()][Switch]$NoDBInfo,
        [Parameter()][Switch]$NoTotal
        )
    Begin{
        # Empty Collector
        [Collections.ArrayList]$Total=@()
        # If DB Info [Default]
        if(-Not$NoDBInfo){
            # DB Info
"##############################

------------------------------
# DB Info                    #
------------------------------
$((Get-BloodHoundDBInfo|Out-String).trim())

##############################"
        }}
    Process{
        Foreach($Obj in $Data){
            # Add to Total
            $Null=$Total.Add($Obj)
            # Output
"
##  $($Obj.group) ##

SID: $($Obj.SID)
Description:
$($Obj.description)

User Count
----------
Direct Members : $($Obj.DirectMbrCount)
Nested Members : $($Obj.NestedMbrCount)
Users w. Paths : $($Obj.UserPathCount)


Top10 - Impact           
--------------

$(($Obj.NodeWeight|Sort Impact -Descending |Where distance -ne 0 |Select -first 10|ft|Out-String).trim())


Top5 User - Impact           
------------------

$(($Obj.NodeWeight|? type -eq user|Sort Impact -Descending |Select -first 5|ft|Out-String).trim())


Top5 Computer - Impact           
----------------------

$(($Obj.NodeWeight|? type -eq Computer|Sort Impact -Descending |Select -first 5|ft|Out-String).trim())


Top5 Group - Impact           
-------------------

$(($Obj.NodeWeight|? type -eq Group|Sort Impact -Descending|Where impact -ne 100|Select -first 5|ft|Out-String).trim())


# Cypher - Query
----------------

$($Obj.Cypher[4])


##############################"
        }}
    End{# If Total
        if(-Not$NoTotal){
            # Target Count
            $TC = $Total.Count
            # Total Path Count
            $PC = ($Total|measure -prop PathCount -sum).sum
            $TI = $Total|TotalImpact


"
## TOTAL IMPACT ##
------------------


Top10 User - TotalImpact [ $TC : $PC : 100 ]
------------------------

$(($TI|Where Type -eq User|Sort Impact -Descending | Select -First 10 | FT | Out-String).trim())


Top10 Computer - TotalImpact [ $TC : $PC : 100 ]
----------------------------

$(($TI|Where Type -eq Computer |Sort Impact -Descending | Select -First 10 | FT | Out-String).trim())


Top10 Group - TotalImpact [ $TC : $PC : 100 ]
-------------------------

$(($TI|Where Type -eq Group|Sort Impact -Descending | Select -First 10 | FT | Out-String).trim())


Top20 Overall - TotalImpact [ $TC : $PC : 100 ]
---------------------------

$(($TI|Sort Impact -Descending | Select -First 20 | FT -AutoSize | Out-String).trim())


##############################

## GROUP COUNT OVERVIEW ##
--------------------------

$($Total| select group,directmbrcount,nestedmbrcount,userpathcount | Out-String)
" 
            }
        }
    }
#####End

###########################################################
