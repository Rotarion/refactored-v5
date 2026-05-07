  const advisorResidentOperatorReadOnlyStatusOps = Object.freeze([
    'detect_state',
    'gather_rapport_snapshot',
    'gather_confirmed_vehicles_status',
    'gather_start_quoting_status',
    'gather_vehicle_add_status',
    'gather_vehicle_row_status',
    'gather_vehicle_edit_status',
    'product_overview_tile_status',
    'customer_summary_overview_status',
    'address_verification_status',
    'prospect_form_status'
  ]);
  const advisorResidentOperatorReadOnlyWaitConditions = Object.freeze([
    'gather_data',
    'is_rapport',
    'duplicate_to_next',
    'vehicle_select_enabled'
  ]);
  const advisorResidentOperatorMutationOps = Object.freeze([
    'click_by_id',
    'click_by_text',
    'click_customer_summary_start_here',
    'click_product_overview_tile',
    'select_vehicle_dropdown_option',
    'prepare_vehicle_row',
    'confirm_potential_vehicle',
    'fill_gather_defaults',
    'fill_participant_modal'
  ]);
  const advisorResidentOperatorRegistry = () => ({
    readOnlyStatusOps: advisorResidentOperatorReadOnlyStatusOps.slice(),
    readOnlyWaitConditions: advisorResidentOperatorReadOnlyWaitConditions.slice(),
    mutationOps: advisorResidentOperatorMutationOps.slice()
  });
  const advisorResidentOperatorFailure = (operator, result, extra = {}) => {
    const page = advisorRunnerReadPage(extra.source || {});
    const payload = Object.assign({
      result,
      blockedReason: safe(extra.blockedReason || '').trim(),
      op: compact(extra.op || '', 100),
      waitConditionName: compact(extra.waitConditionName || '', 100),
      requestId: compact(extra.requestId || '', 120),
      version: operator && operator.version || '',
      buildHash: operator && operator.buildHash || '',
      installedAt: operator && operator.installedAt || '',
      url: page.url,
      routeFamily: page.routeFamily,
      detectedState: page.detectedState,
      elapsedMs: safe(extra.elapsedMs || '0'),
      mutatingRequestRefused: safe(extra.mutatingRequestRefused || '0')
    }, extra.fields || {});
    delete payload.source;
    operator.lastResult = {
      requestId: payload.requestId,
      op: payload.op,
      waitConditionName: payload.waitConditionName,
      result,
      blockedReason: payload.blockedReason,
      elapsedMs: payload.elapsedMs,
      valueLength: '0'
    };
    return linesOut(payload);
  };
  const advisorResidentOperatorStatusFields = (operator, source = {}) => {
    const page = advisorRunnerReadPage(source);
    const expectedBuildHash = safe(source.__residentExpectedBuildHash || source.expectedBuildHash).trim();
    const expectedHost = safe(source.__residentExpectedHost || source.expectedHost).trim();
    let result = 'OK';
    let blockedReason = '';
    if (expectedBuildHash && expectedBuildHash !== operator.buildHash) {
      result = 'STALE_BUILD';
      blockedReason = 'stale-build';
    } else if (expectedHost && !page.url.includes(expectedHost)) {
      result = 'WRONG_CONTEXT';
      blockedReason = 'wrong-context';
    }
    return {
      result,
      blockedReason,
      running: '0',
      stopRequested: '0',
      version: operator.version,
      buildHash: operator.buildHash,
      installedAt: operator.installedAt,
      url: page.url,
      routeFamily: page.routeFamily,
      detectedState: page.detectedState,
      lastResult: operator.lastResult && operator.lastResult.result || '',
      lastBlockedReason: operator.lastResult && operator.lastResult.blockedReason || '',
      requestCount: String(operator.requestCount || 0),
      readOnlyStatusOpCount: String(advisorResidentOperatorReadOnlyStatusOps.length),
      readOnlyWaitConditionCount: String(advisorResidentOperatorReadOnlyWaitConditions.length),
      mutationOpCount: String(advisorResidentOperatorMutationOps.length)
    };
  };
  const createAdvisorResidentOperator = (version, buildHash) => {
    const operator = {
      version,
      buildHash,
      installedAt: new Date(advisorRunnerNow()).toISOString(),
      registry: advisorResidentOperatorRegistry(),
      requestCount: 0,
      lastResult: null,
      health(source = {}) {
        return advisorResidentOperatorStatusFields(this, source);
      },
      status(source = {}) {
        return advisorResidentOperatorStatusFields(this, source);
      },
      run(opName, source = {}, requestId = '') {
        const started = advisorRunnerNow();
        const opText = safe(opName).trim();
        const args = source && typeof source === 'object' ? source : {};
        const conditionName = opText === 'wait_condition' ? safe(args.name || args.conditionName).trim() : '';
        const elapsed = () => String(Math.max(0, advisorRunnerNow() - started));
        this.requestCount += 1;

        try {
          if (!opText) {
            return advisorResidentOperatorFailure(this, 'REFUSED', {
              op: opText,
              requestId,
              source: args,
              elapsedMs: elapsed(),
              blockedReason: 'missing-op'
            });
          }

          const status = this.status(args);
          if (status.result === 'STALE_BUILD') {
            return advisorResidentOperatorFailure(this, 'STALE_BUILD', {
              op: opText,
              waitConditionName: conditionName,
              requestId,
              source: args,
              elapsedMs: elapsed(),
              blockedReason: 'stale-build'
            });
          }
          if (status.result === 'WRONG_CONTEXT') {
            return advisorResidentOperatorFailure(this, 'WRONG_CONTEXT', {
              op: opText,
              waitConditionName: conditionName,
              requestId,
              source: args,
              elapsedMs: elapsed(),
              blockedReason: 'wrong-context'
            });
          }

          if (opText === 'wait_condition') {
            if (!advisorResidentOperatorReadOnlyWaitConditions.includes(conditionName)) {
              return advisorResidentOperatorFailure(this, 'REFUSED', {
                op: opText,
                waitConditionName: conditionName,
                requestId,
                source: args,
                elapsedMs: elapsed(),
                blockedReason: 'wait-condition-not-allowed'
              });
            }
            const value = readAdvisorWaitCondition(Object.assign({}, args, { name: conditionName }));
            this.lastResult = {
              requestId: compact(requestId, 120),
              op: opText,
              waitConditionName: conditionName,
              result: 'OK',
              blockedReason: '',
              elapsedMs: elapsed(),
              valueLength: String(safe(value).length)
            };
            return value;
          }

          if (advisorResidentOperatorMutationOps.includes(opText)) {
            if (!advisorRunnerBool(args.__residentMutationEnabled || args.mutationEnabled)) {
              return advisorResidentOperatorFailure(this, 'REFUSED', {
                op: opText,
                requestId,
                source: args,
                elapsedMs: elapsed(),
                blockedReason: 'mutation-disabled',
                mutatingRequestRefused: '1'
              });
            }
            return advisorResidentOperatorFailure(this, 'REFUSED', {
              op: opText,
              requestId,
              source: args,
              elapsedMs: elapsed(),
              blockedReason: 'mutation-not-implemented',
              mutatingRequestRefused: '1'
            });
          }

          if (!advisorResidentOperatorReadOnlyStatusOps.includes(opText)) {
            return advisorResidentOperatorFailure(this, 'REFUSED', {
              op: opText,
              requestId,
              source: args,
              elapsedMs: elapsed(),
              blockedReason: 'op-not-allowed'
            });
          }

          const value = readAdvisorStatusOp(opText, args);
          if (!safe(value).trim()) {
            return advisorResidentOperatorFailure(this, 'EMPTY', {
              op: opText,
              requestId,
              source: args,
              elapsedMs: elapsed(),
              blockedReason: 'empty-result'
            });
          }
          this.lastResult = {
            requestId: compact(requestId, 120),
            op: opText,
            waitConditionName: '',
            result: 'OK',
            blockedReason: '',
            elapsedMs: elapsed(),
            valueLength: String(safe(value).length)
          };
          return value;
        } catch (err) {
          return advisorResidentOperatorFailure(this, 'ERROR', {
            op: opText,
            waitConditionName: conditionName,
            requestId,
            source: args,
            elapsedMs: elapsed(),
            blockedReason: 'js-error',
            fields: { message: compact((err && err.message) || err, 240) }
          });
        }
      }
    };
    return operator;
  };
  const advisorResidentOperatorCommand = (source = {}) => {
    const host = advisorRunnerHost();
    if (!host) {
      return linesOut({
        result: 'ERROR',
        blockedReason: 'no-global-host',
        version: '',
        buildHash: '',
        installedAt: '',
        url: compact(pageUrl(), 240),
        routeFamily: 'UNKNOWN',
        detectedState: 'NO_CONTEXT'
      });
    }
    const command = safe(source.command || source.cmd || 'bootstrap').trim() || 'bootstrap';
    const version = safe(source.version || 'phase1').trim() || 'phase1';
    const buildHash = safe(source.buildHash || 'dev').trim() || 'dev';
    const existing = host.__advisorQuoteResidentOperator || null;

    if (command === 'status' || command === 'health') {
      if (!existing || typeof existing.run !== 'function') {
        const page = advisorRunnerReadPage(source);
        return linesOut({
          result: 'MISSING',
          blockedReason: 'missing-resident-operator',
          version: '',
          buildHash: '',
          installedAt: '',
          url: page.url,
          routeFamily: page.routeFamily,
          detectedState: page.detectedState,
          requestCount: '0'
        });
      }
      return linesOut(existing.status(source));
    }

    if (command !== 'bootstrap') {
      return linesOut({
        result: 'REFUSED',
        blockedReason: 'unknown-command',
        command: compact(command, 80)
      });
    }

    if (existing && existing.version === version && existing.buildHash === buildHash && typeof existing.run === 'function') {
      const status = existing.status(source);
      return linesOut(Object.assign({}, status, {
        result: 'ALREADY_BOOTSTRAPPED',
        message: 'resident-operator-present'
      }));
    }
    if (existing && !advisorRunnerBool(source.replaceStale)) {
      const status = existing.status(source);
      return linesOut(Object.assign({}, status, {
        result: 'STALE',
        blockedReason: 'replace-stale-required',
        message: 'replaceStale-required'
      }));
    }

    const operator = createAdvisorResidentOperator(version, buildHash);
    host.__advisorQuoteResidentOperator = operator;
    const status = operator.status(source);
    return linesOut(Object.assign({}, status, {
      result: existing ? 'STALE_REPLACED' : 'OK',
      message: existing ? 'resident-operator-replaced' : 'resident-operator-created'
    }));
  };
