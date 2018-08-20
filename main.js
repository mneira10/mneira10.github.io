function main() {
    console.log('ejecuta')
    $('#circleProject').hide();
    $('.circlesP').on('click',function(){
        $('#circleProject').slideToggle(400)
        startCircles();
      })
}


$(document).ready(main)