function step!(community)

    if !community.loaded
        loadToPlatform!(community)
    end

    interactionStep!(community)
    integrationStep!(community)
    localStep!(community)
    globalStep!(community)
    update!(community)

end