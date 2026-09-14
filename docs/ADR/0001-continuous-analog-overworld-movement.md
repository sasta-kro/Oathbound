# Continuous analog overworld movement

The overworld uses continuous eight-direction movement through `Input.get_vector` and `move_and_slide()`. Player and wild-creature collision shapes are 40 pixels inside 48-pixel map cells; the grid supports map placement and distance tuning only. This provides smooth movement while keeping map measurements consistent.
