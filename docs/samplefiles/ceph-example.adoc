[options="header"]
|===
|Pool name|Pool type|Replicas|# of OSDs|% of Data|Target PGs per OSD|Suggested PG Count
|images|Replicated|3|56|10|100|256
|metrics|Replicated|3|56|0|100|32
|backups|Replicated|3|56|15|100|256
|vms|Replicated|3|56|30|100|512
|volumes|Replicated|3|56|30|100|512
|.rgw.root|Replicated|3|56|0.1|100|32
|defaults.rgw.buckets.data|Replicated|3|56|10|100|256
|defaults.rgw.buckets.index|Replicated|3|56|3|100|64
|default.rgw.control|Replicated|3|56|0.1|100|32
|default.rgw.meta|Replicated|3|56|0.1|100|32
|default.rgw.log|Replicated|3|56|0.1|100|32
|===
