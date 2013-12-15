var RentalService = (function() {

    var pub = {};

    pub.itemListInit = function() {
        $("#item-table").find('a.remove_item').on("click", function (e) {
            var element = $(this);
            var tmp = element.closest('tr').find('td')[0];
            var name = $(tmp).text();
            var tmp2 = element.closest('tr').find('td')[1];
            var model = $(tmp2).text();
            var modal = $("#delete_modal");
            modal.find(".modal-title").text("Remove");
            modal.find(".modal-body").html("<p>Do you want to remove <strong>" + name + " " + model + "</strong>?</p>");
            modal.find(".delete").data('url', element.data('remove-item'));

            modal.modal();
            return false;
        });

        modalInit();
    };

    pub.freeItemListInit = function() {
        $("#item-table").find('a.request_item').on("click", function (e) {
            var element = $(this);
            var tmp = element.closest('tr').find('td')[0];
            var name = $(tmp).text();
            var tmp = element.closest('tr').find('td')[1];
            var model = $(tmp).text();
            var modal = $("#delete_modal");
            modal.find(".modal-title").text("Rent");
            modal.find(".modal-body").html("<p>Do you want to rent <strong>" + name + " " + model + "</strong>?</p>");
            modal.find(".delete").data('url', element.data('request-item'));

            modal.modal();
            return false;
        });

        modalInit();
    };

    pub.userListInit = function() {
        $("#user-records-table").find('a.return_item').on("click", function (e) {
            var element = $(this);
            var tmp = element.closest('tr').find('td')[0];
            var name = $(tmp).text();
            var tmp2 = element.closest('tr').find('td')[1];
            var model = $(tmp2).text();
            var modal = $("#delete_modal");
            modal.find(".modal-title").text("Return");
            modal.find(".modal-body").html("<p>Do you want to return <strong>" + name + " " + model + "</strong>?</p>");
            modal.find(".delete").data('url', element.data('return-item'));

            modal.modal();
            return false;
        });

        modalInit();
    };

/*
    pub.detailedListInit = function() {
        $("#item-detailed-table").find('a.remove_item').on("click", function (e) {
            var element = $(this);
            var tmp = element.closest('tr').find('td')[0];
            var name = $(tmp).text();
            var tmp2 = element.closest('tr').find('td')[1];
            var model = $(tmp2).text();
            var modal = $("#delete_modal");
            modal.find(".modal-title").text("Remove");
            modal.find(".modal-body").html("<p>Do you want to remove <strong>" + name + " " + model + "</strong>?</p>");
            modal.find(".delete").data('url', element.data('remove-item'));

            modal.modal();
            return false;
        });

        modalInit();
    };
*/

    pub.positionListInit = function() {
        $("#position-table").find('a.delete_position').on("click", function (e) {
            var element = $(this);
            var tmp = element.closest('tr').find('td')[0];
            var name = $(tmp).text();
            var modal = $("#delete_modal");
            modal.find(".modal-title").text("Remove");
            modal.find(".modal-body").html("<p>Do you want to remove position <strong>" + name + "</strong>?</p>");
            modal.find(".delete").data('url', element.data('delete-position'));

            modal.modal();
            return false;
        });


        $("#position-table").find('a.employ').on("click", function (e) {
            var element = $(this);
            var tmp = element.closest('tr').find('td')[0];
            var position = $(tmp).text();
            var modal = $("#employ_modal");
            modal.find(".modal-title").text("Employment");
            modal.find(".modal-body").html("<p>Do you want to employ user at position position <strong>" + position + "</strong>?</p>");
            modal.find(".yes").data('url', element.data('delete-position'));

            modal.modal();
            return false;
        });

        modalInit();
    };

    pub.takenPositionListInit = function() {
        $("#taken-position-table").find('a.end_occupation').on("click", function (e) {
            var element = $(this);
            var tmp = element.closest('tr').find('td')[0];
            var position = $(tmp).text();
            var tmp2 = element.closest('tr').find('td')[2];
            var name = $(tmp2).text();
            var modal = $("#delete_modal");
            modal.find(".modal-title").text("Dismissal");
            modal.find(".modal-body").html("<p>Do you want to dismiss employee <strong>" + name + "</strong> from position " + position + "?</p>");
            modal.find(".delete").data('url', element.data('end-occupation'));

            modal.modal();
            return false;
        });
    }

    pub.occupationListInit = function() {
        $("#occupation-table").find('a.end_occupation').on("click", function (e) {
            var element = $(this);
            var tmp = element.closest('tr').find('td')[0];
            var name = $(tmp).text();
            var modal = $("#delete_modal");
            modal.find(".modal-title").text("Employment change");
            modal.find(".modal-body").html("<p>Do you want to dismiss employee <strong>" + name + "</strong>?</p>");
            modal.find(".delete").data('url', element.data('end-occupation'));

            modal.modal();
            return false;
        });

        $("#occupation-table").find('a.renew_occupation').on("click", function (e) {
            var element = $(this);
            var tmp = element.closest('tr').find('td')[0];
            var name = $(tmp).text();
            var tmp2 = element.closest('tr').find('td')[1];
            var position = $(tmp2).text();
            var modal = $("#delete_modal");
            modal.find(".modal-title").text("Restore employment record");
            modal.find(".modal-body").html("<p>Do you want to employ <strong>" + name + "</strong> as " + position + " ?</p>");
            modal.find(".delete").data('url', element.data('renew-occupation'));

            modal.modal();
            return false;
        });

        modalInit();
    };

    var modalInit = function(){
        $("#delete_modal").find(".delete").on("click", function (e) {
            var url = $(this).data("url");

            $.ajax({
                url: url,
                method: 'POST',
                beforeSend: function(xhr, settings) {
                    xhr.setRequestHeader("X-CSRFToken", $.cookie('csrftoken'));
                },
                success: function(data) {
                    document.location.reload();
                },
                error: function(xhr, data, error) {

                }
            });
        });

        $("#employ_modal").find(".yes").on("click", function (e) {
            var url = $(this).data("url");

            $.ajax({
                url: url,
                method: 'POST',
                beforeSend: function(xhr, settings) {
                    xhr.setRequestHeader("X-CSRFToken", $.cookie('csrftoken'));
                },
                success: function(data) {
                    document.location.reload();
                },
                error: function(xhr, data, error) {

                }
            });
        });

    };

    return pub;
}());