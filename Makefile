RECORDS := $(patsubst %.sh,%,$(patsubst recs/%,%,$(wildcard recs/*.sh)))

.DEFAULT_GOAL := replay

.PHONY: replay
replay: $(RECORDS)

define gen_replay_targets
.PHONY: $(1)
$(1):
	@recs/$(1).sh
endef

$(foreach RECORD,$(RECORDS),\
	$(eval $(call gen_replay_targets,$(RECORD)))\
)

.PHONY: replay/list
replay/list:
	@echo $(RECORDS)
