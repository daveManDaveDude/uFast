uFast/Domain/ActiveFastLiveActivityCoordinator.swift
Comment on lines +165 to +167
        _ = await reconcile()
        foregroundAutomaticAttempted = true
        return await attemptAutomaticRequest(kind: .foreground)

 P2 Badge Recheck foreground state after reconciliation

When reconciliation suspends while updating or ending an existing ActivityKit record, the scene can become inactive and didBecomeInactive() can clear foregroundIsActive before this continuation resumes. These lines then unconditionally mark the foreground attempt and may request a replacement Live Activity while the app is already backgrounded, violating the foreground-only recovery contract; revalidate the activation state or generation after await reconcile() before attempting the request.